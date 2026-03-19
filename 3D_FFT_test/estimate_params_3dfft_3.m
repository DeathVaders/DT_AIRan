function est = estimate_params_3dfft_3(H_obs, Rx_ant_spacing, B, OS_x, OS_y, OS_delay, num_peaks)
% estimate_params_3dfft
% Add one-time visualization of the 3D-FFT power spectrum during peak selection.

    [Nx, Ny, Nc] = size(H_obs);

    % FFT sizes
    Nx_fft = OS_x * Nx;
    Ny_fft = OS_y * Ny;
    Ntau_fft = OS_delay * Nc;

    % 3D windows
    wx = hann(Nx);
    wy = hann(Ny);
    wt = hann(Nc);

    H_win = H_obs .* reshape(wx, [], 1, 1) ...
                  .* reshape(wy, 1, [], 1) ...
                  .* reshape(wt, 1, 1, []);

    % 3D-FFT
    Sx = fftshift(fft(H_win, Nx_fft, 1), 1);
    Sxy = fftshift(fft(Sx, Ny_fft, 2), 2);
    S = ifft(Sxy, Ntau_fft, 3);
    P = abs(S).^2;

    % Candidate peak extraction
    num_candidates = min(5 * num_peaks, numel(P));
    [~, idx_all] = maxk(P(:), num_candidates);
    [ix_all, iy_all, itau_all] = ind2sub(size(P), idx_all);

    % Peak deduplication
    min_sep_x = max(1, round(OS_x));
    min_sep_y = max(1, round(OS_y));
    min_sep_tau = max(1, round(OS_delay));

    keep = true(length(idx_all), 1);

    for i = 1:length(idx_all)
        if ~keep(i)
            continue;
        end

        for j = i+1:length(idx_all)
            if ~keep(j)
                continue;
            end

            cond_x = abs(ix_all(i) - ix_all(j)) <= min_sep_x;
            cond_y = abs(iy_all(i) - iy_all(j)) <= min_sep_y;
            cond_tau = abs(itau_all(i) - itau_all(j)) <= min_sep_tau;

            if cond_x && cond_y && cond_tau
                keep(j) = false;
            end
        end
    end

    idx = idx_all(keep);
    ix = ix_all(keep);
    iy = iy_all(keep);
    itau = itau_all(keep);

    if numel(idx) > num_peaks
        idx = idx(1:num_peaks);
        ix = ix(1:num_peaks);
        iy = iy(1:num_peaks);
        itau = itau(1:num_peaks);
    end

    nu_x = (-Nx_fft/2 : Nx_fft/2-1) / Nx_fft;
    nu_y = (-Ny_fft/2 : Ny_fft/2-1) / Ny_fft;
    tau_grid = (0:Ntau_fft-1) / (OS_delay * B);

    % Plot only once in each run of main_2.m
    if ~isappdata(0, 'plot_3dfft_power_once')
        setappdata(0, 'plot_3dfft_power_once', false);
    end

    if ~getappdata(0, 'plot_3dfft_power_once')
        P_xy = max(P, [], 3);
        [~, itau_peak] = max(squeeze(max(max(P, [], 1), [], 2)));
        P_tau_slice = P(:, :, itau_peak);

        figure('Name', '3D-FFT Power Spectrum', 'Color', 'w');

        subplot(1, 2, 1);
        imagesc(nu_y, nu_x, 10 * log10(P_xy + eps));
        axis xy;
        xlabel('u_y');
        ylabel('u_x');
        title('Max over delay');
        colorbar;
        hold on;
        plot(nu_y(iy), nu_x(ix), 'ro', 'MarkerSize', 8, 'LineWidth', 1.5);
        hold off;

        subplot(1, 2, 2);
        imagesc(nu_y, nu_x, 10 * log10(P_tau_slice + eps));
        axis xy;
        xlabel('u_y');
        ylabel('u_x');
        title(sprintf('Delay slice at tau = %.3e s', tau_grid(itau_peak)));
        colorbar;
        hold on;
        plot(nu_y(iy), nu_x(ix), 'ro', 'MarkerSize', 8, 'LineWidth', 1.5);
        hold off;

        setappdata(0, 'plot_3dfft_power_once', true);
    end

    % Recover ux / uy / tau
    ux_grid = nu_x;
    uy_grid = nu_y;

    ux_est = ux_grid(ix).';
    uy_est = uy_grid(iy).';
    tau_est = tau_grid(itau).';

    % ux, uy -> azimuth, elevation
    r = sqrt(ux_est.^2 + uy_est.^2) / Rx_ant_spacing;
    r = min(max(r, 0), 1);

    phi_est = asind(r);
    az_est = atan2d(uy_est, ux_est);
    el_est = 90 - phi_est;

    alpha_est = estimateAlphaLS3D(H_obs, az_est, el_est, tau_est, Rx_ant_spacing, B);

    est = struct();
    est.az = az_est(:);
    est.el = el_est(:);
    est.tau = tau_est(:);
    est.alpha = alpha_est(:);
    est.P = P;
    est.ux_grid = ux_grid;
    est.uy_grid = uy_grid;
    est.tau_grid = tau_grid;
    est.ix = ix;
    est.iy = iy;
    est.itau = itau;
end

function alpha_hat = estimateAlphaLS3D(H, az_hat_deg, el_hat_deg, tau_hat_s, Rx_ant_spacing, B)
% estimateAlphaLS3D
% Least-squares alpha estimation with the original 3D model.

    [Nx, Ny, Nc] = size(H);

    az_hat_deg = az_hat_deg(:);
    el_hat_deg = el_hat_deg(:);
    tau_hat_s = tau_hat_s(:);

    L_est = numel(az_hat_deg);

    if L_est == 0
        alpha_hat = [];
        return;
    end

    df = B / Nc;
    f = (0:Nc-1) * df;

    nx = (0:Nx-1).';
    ny = (0:Ny-1);
    A = zeros(Nx * Ny * Nc, L_est);

    for l = 1:L_est
        phi_l = 90 - el_hat_deg(l);

        ux_l = Rx_ant_spacing * sind(phi_l) * cosd(az_hat_deg(l));
        uy_l = Rx_ant_spacing * sind(phi_l) * sind(az_hat_deg(l));

        a_x = exp(1j * 2*pi * ux_l * nx);
        a_y = exp(1j * 2*pi * uy_l * ny);
        a_f = exp(-1j * 2*pi * f * tau_hat_s(l));

        atom = reshape(a_x, [Nx, 1, 1]) .* ...
               reshape(a_y, [1, Ny, 1]) .* ...
               reshape(a_f, [1, 1, Nc]);

        A(:, l) = atom(:);
    end

    h = H(:);
    alpha_hat = A \ h;
end
