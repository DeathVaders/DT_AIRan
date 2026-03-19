function est = estimate_params_3dfft_2(H_obs, Rx_ant_spacing, B, OS_x, OS_y, OS_delay, num_peaks)
% estimate_params_3dfft
% SIC-based 3D-FFT path estimation with the original model unchanged.

    [Nx, Ny, Nc] = size(H_obs);

    % FFT sizes
    Nx_fft = OS_x * Nx;
    Ny_fft = OS_y * Ny;
    Ntau_fft = OS_delay * Nc;

    % 3D windows
    wx = hann(Nx);
    wy = hann(Ny);
    wt = hann(Nc);

    % Grids, kept consistent with the original implementation
    nu_x = (-Nx_fft/2 : Nx_fft/2-1) / Nx_fft;
    nu_y = (-Ny_fft/2 : Ny_fft/2-1) / Ny_fft;
    ux_grid = nu_x;
    uy_grid = nu_y;
    tau_grid = (0:Ntau_fft-1) / (OS_delay * B);

    % SIC initialization
    H_res = H_obs;
    az_list = zeros(num_peaks, 1);
    el_list = zeros(num_peaks, 1);
    tau_list = zeros(num_peaks, 1);
    alpha_list = complex(zeros(num_peaks, 1));
    ix_list = zeros(num_peaks, 1);
    iy_list = zeros(num_peaks, 1);
    itau_list = zeros(num_peaks, 1);

    first_peak_val = [];
    P_first = [];
    num_detected = 0;
    peak_stop_ratio = 1e-3;

    % Successive detection and cancellation
    for p = 1:num_peaks
        % a) Windowing and 3D-FFT on the current residual
        H_win = H_res .* reshape(wx, [], 1, 1) ...
                      .* reshape(wy, 1, [], 1) ...
                      .* reshape(wt, 1, 1, []);

        Sx = fftshift(fft(H_win, Nx_fft, 1), 1);
        Sxy = fftshift(fft(Sx, Ny_fft, 2), 2);
        S = ifft(Sxy, Ntau_fft, 3);
        P = abs(S).^2;

        % b) Take only the strongest peak
        [peak_val, idx_peak] = max(P(:));
        [ix, iy, itau] = ind2sub(size(P), idx_peak);

        if isempty(first_peak_val)
            first_peak_val = peak_val;
            P_first = P;
        end

        % Early stop if the current peak is too small
        if first_peak_val <= 0 || peak_val < peak_stop_ratio * first_peak_val
            break;
        end

        % c) Recover ux / uy / tau and map to az / el
        ux_est = ux_grid(ix);
        uy_est = uy_grid(iy);
        tau_est = tau_grid(itau);

        r = sqrt(ux_est^2 + uy_est^2) / Rx_ant_spacing;
        r = min(max(r, 0), 1);

        phi_est = asind(r);
        az_est = atan2d(uy_est, ux_est);
        el_est = 90 - phi_est;

        % d) LS estimate for the current single path only
        alpha_est = estimateAlphaLS3D(H_res, az_est, el_est, tau_est, Rx_ant_spacing, B);

        % e) Reconstruct the current path
        H_path = reconstructSinglePath3D( ...
            Nx, Ny, Nc, az_est, el_est, tau_est, alpha_est, Rx_ant_spacing, B);

        % f) Residual update
        H_res = H_res - H_path;

        % g) Save estimates
        num_detected = num_detected + 1;
        az_list(num_detected) = az_est;
        el_list(num_detected) = el_est;
        tau_list(num_detected) = tau_est;
        alpha_list(num_detected) = alpha_est;

        % h) Save peak locations
        ix_list(num_detected) = ix;
        iy_list(num_detected) = iy;
        itau_list(num_detected) = itau;
    end

    est = struct();
    est.az = az_list(1:num_detected);
    est.el = el_list(1:num_detected);
    est.tau = tau_list(1:num_detected);
    est.alpha = alpha_list(1:num_detected);

    % Save the first-round spectrum for inspection
    if isempty(P_first)
        est.P = zeros(Nx_fft, Ny_fft, Ntau_fft);
    else
        est.P = P_first;
    end

    est.ux_grid = ux_grid;
    est.uy_grid = uy_grid;
    est.tau_grid = tau_grid;
    est.ix = ix_list(1:num_detected);
    est.iy = iy_list(1:num_detected);
    est.itau = itau_list(1:num_detected);
end

function H_path = reconstructSinglePath3D(Nx, Ny, Nc, az_deg, el_deg, tau_s, alpha, Rx_ant_spacing, B)
% reconstructSinglePath3D
% Reconstruct one path using the same model as estimateAlphaLS3D.

    df = B / Nc;
    f = (0:Nc-1) * df;

    phi = 90 - el_deg;
    ux = Rx_ant_spacing * sind(phi) * cosd(az_deg);
    uy = Rx_ant_spacing * sind(phi) * sind(az_deg);

    nx = (0:Nx-1).';
    ny = (0:Ny-1);

    a_x = exp(1j * 2*pi * ux * nx);
    a_y = exp(1j * 2*pi * uy * ny);
    a_f = exp(-1j * 2*pi * f * tau_s);

    H_path = alpha .* reshape(a_x, [Nx, 1, 1]) ...
                   .* reshape(a_y, [1, Ny, 1]) ...
                   .* reshape(a_f, [1, 1, Nc]);
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
