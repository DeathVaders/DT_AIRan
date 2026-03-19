function est = estimate_params_3dfft_4(H_obs, Rx_ant_spacing, B, OS_x, OS_y, OS_delay, num_peaks, ...
                                       do_plot, save_plot, save_dir, plot_tag, true_az, true_el, true_tau)
% estimate_params_3dfft
% 3D-FFT parameter estimation with optional spectrum visualization.

    if nargin < 8,  do_plot = false; end
    if nargin < 9,  save_plot = false; end
    if nargin < 10, save_dir = '.'; end
    if nargin < 11, plot_tag = 'sample'; end
    if nargin < 12, true_az = []; end
    if nargin < 13, true_el = []; end
    if nargin < 14, true_tau = []; end

    [Nx, Ny, Nc] = size(H_obs);

    % FFT sizes
    Nx_fft = OS_x * Nx;
    Ny_fft = OS_y * Ny;
    Ntau_fft = OS_delay * Nc;

    % 3D windows
    wx = blackman(Nx);
    wy = blackman(Ny);
    %wt = hann(Nc);
    wt = blackman(Nc);
    H_win = H_obs .* reshape(wx, [], 1, 1) ...
                  .* reshape(wy, 1, [], 1) ...
                  .* reshape(wt, 1, 1, []);

    % 3D-FFT
    Sx = fftshift(fft(H_win, Nx_fft, 1), 1);
    Sxy = fftshift(fft(Sx, Ny_fft, 2), 2);
    S = ifft(Sxy, Ntau_fft, 3);
    P = abs(S).^2;

    % Candidate peak extraction
    num_candidates = min(10 * num_peaks, numel(P));
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

    if do_plot
        num_plot_peaks = min(60, numel(P));
        [peak_vals_plot, idx_plot] = maxk(P(:), num_plot_peaks);
        [ix_plot, iy_plot, itau_plot] = ind2sub(size(P), idx_plot);

        ux_plot = nu_x(ix_plot);
        uy_plot = nu_y(iy_plot);
        tau_plot = tau_grid(itau_plot);

        figure('Color','w');
        scatter3(uy_plot, ux_plot, tau_plot*1e9, 60, 10*log10(peak_vals_plot+eps), 'filled');
        xlabel('u_y'); ylabel('u_x'); zlabel('\tau (ns)');
        title(['3D FFT peaks - ' plot_tag]);
        grid on; colorbar; view(45,30);
        hold on;

        scatter3(uy_est, ux_est, tau_est*1e9, 120, 'ro', 'LineWidth', 1.8);

        if ~isempty(true_az)
            phi_true = 90 - true_el(:);
            ux_true = Rx_ant_spacing * sind(phi_true) .* cosd(true_az(:));
            uy_true = Rx_ant_spacing * sind(phi_true) .* sind(true_az(:));

            scatter3(uy_true, ux_true, true_tau(:)*1e9, 140, 'kp', 'LineWidth', 1.8);
        end

        if save_plot
            if ~exist(save_dir,'dir'), mkdir(save_dir); end
            exportgraphics(gcf, fullfile(save_dir,['spectrum_' plot_tag '.png']),'Resolution',300);
        end
    end

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
