function est = estimate_params_3dfft(H_obs, Rx_ant_spacing, B, OS_x, OS_y, OS_delay, num_peaks)
% estimate_params_3dfft
%   对三维信道张量 H_obs(Nx,Ny,Nc) 做 3D-FFT，
%   恢复 AoA 方位角、AoA 俯仰角、时延 tau
%
% 输入：
%   H_obs           : 大小 [Nx, Ny, Nc] 的完整信道张量
%   Rx_ant_spacing  : 阵元间距（单位：波长）
%   B               : 总带宽
%   OS_x            : x维过采样倍数
%   OS_y            : y维过采样倍数
%   OS_delay        : delay维过采样倍数
%   num_peaks       : 需要提取的峰值数
%
% 输出：
%   est             : 结构体，包含：
%       .az         : 估计方位角（度）
%       .el         : 估计俯仰角（度）
%       .tau        : 估计时延（秒）
%       .alpha      : 峰值复数值（粗略当作alpha）
%       .P          : 3D功率谱
%       .ux_grid
%       .uy_grid
%       .tau_grid
%       .ix
%       .iy
%       .itau
%
%   对应模型：
%       H(nx,ny,k) = sum_l alpha_l *
%                    exp(j2pi(nx*ux_l + ny*uy_l)) *
%                    exp(-j2pi f_k tau_l)
%
%   3D-FFT首先恢复的是 (ux, uy, tau)，
%   然后再由 (ux, uy) 映射为 (azimuth, elevation)。

    [Nx, Ny, Nc] = size(H_obs);

    % FFT点数（过采样）
    Nx_fft = OS_x * Nx;
    Ny_fft = OS_y * Ny;
    Ntau_fft = OS_delay * Nc;

    % ===== 1) 加三维窗函数，降低旁瓣 =====
    wx = hann(Nx);
    wy = hann(Ny);
    wt = hann(Nc);

    H_win = H_obs .* reshape(wx, [], 1, 1) ...
                  .* reshape(wy, 1, [], 1) ...
                  .* reshape(wt, 1, 1, []);

    % ===== 2) 3D-FFT =====
    % x维 FFT
    Sx = fftshift(fft(H_win, Nx_fft, 1), 1);

    % y维 FFT
    Sxy = fftshift(fft(Sx, Ny_fft, 2), 2);

    % delay维 FFT（沿子载波维）
    S = ifft(Sxy, Ntau_fft, 3);

    % 功率谱
    P = abs(S).^2;

    % ===== 3) 取最大峰 =====
%    num_peaks = min(num_peaks, numel(P));
%    [~, idx] = maxk(P(:), num_peaks);
%    [ix, iy, itau] = ind2sub(size(P), idx);
       % ===== 3) 先取更多候选峰 =====
   num_candidates = min(5*num_peaks, numel(P));
   [~, idx_all] = maxk(P(:), num_candidates);
   [ix_all, iy_all, itau_all] = ind2sub(size(P), idx_all);

   % ===== 3.1) 去除过近的重复峰 =====
   min_sep_x   = max(1, round(OS_x));
   min_sep_y   = max(1, round(OS_y));
   min_sep_tau = max(1, round(OS_delay));

   keep = true(length(idx_all),1);

   for i = 1:length(idx_all)
       if ~keep(i)
           continue;
       end

       for j = i+1:length(idx_all)
           if ~keep(j)
               continue;
           end

           cond_x   = abs(ix_all(i)   - ix_all(j))   <= min_sep_x;
           cond_y   = abs(iy_all(i)   - iy_all(j))   <= min_sep_y;
           cond_tau = abs(itau_all(i) - itau_all(j)) <= min_sep_tau;

           if cond_x && cond_y && cond_tau
               keep(j) = false;
           end
       end
   end

   idx  = idx_all(keep);
   ix   = ix_all(keep);
   iy   = iy_all(keep);
   itau = itau_all(keep);

   % 最终只保留前 num_peaks 个
   if numel(idx) > num_peaks
       idx  = idx(1:num_peaks);
       ix   = ix(1:num_peaks);
       iy   = iy(1:num_peaks);
       itau = itau(1:num_peaks);
   end

    % ===== 4) 构造 ux / uy / tau 栅格 =====
    % 阵元间距是以"波长"为单位的，所以 FFT 恢复出来的是 d*sin(phi)cos(theta) 这类量
    nu_x = (-Nx_fft/2 : Nx_fft/2-1) / Nx_fft;
    nu_y = (-Ny_fft/2 : Ny_fft/2-1) / Ny_fft;

    % 对应 ux = d*sin(phi)cos(theta), uy = d*sin(phi)sin(theta)
    ux_grid = nu_x;
    uy_grid = nu_y;

    tau_grid = (0:Ntau_fft-1) / (OS_delay * B);

    ux_est = ux_grid(ix).';
    uy_est = uy_grid(iy).';
    tau_est = tau_grid(itau).';

    % ===== 5) ux, uy -> azimuth, elevation =====
    % r = sin(phi)
    % 但这里 ux = d * sin(phi)cos(theta), uy = d * sin(phi)sin(theta)
    % 所以:
    %   r = sqrt(ux^2 + uy^2) / d
    %   phi = asind(r)
    %   az  = atan2d(uy, ux)
    %
    %  AoA_el 与这里的 phi 关系为：
    %   DoA_phi = 90 - AoA_el
    %   => AoA_el = 90 - phi

    r = sqrt(ux_est.^2 + uy_est.^2) / Rx_ant_spacing;
    r = min(max(r, 0), 1);

    phi_est = asind(r);          % 倾角
    az_est  = atan2d(uy_est, ux_est);
    el_est  = 90 - phi_est;      % 转回原来的俯仰角定义

    %est = struct();
    %est.az = az_est(:);
    %est.el = el_est(:);
    %est.tau = tau_est(:);
    %est.alpha = S(idx);
    %est.P = P;
    %est.ux_grid = ux_grid;
    %est.uy_grid = uy_grid;
    %est.tau_grid = tau_grid;
    %est.ix = ix;
    %est.iy = iy;
    %est.itau = itau;
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
%   在已估计的 az / el / tau 条件下，
%   用最小二乘法估计每条路径的复增益 alpha
%
% 模型：
%   H(nx,ny,k) = sum_l alpha_l *
%                exp(j2pi(nx*ux_l + ny*uy_l)) *
%                exp(-j2pi f_k tau_l)
%
% 其中：
%   ux = d*sin(phi)*cos(az)
%   uy = d*sin(phi)*sin(az)
%   el = 90 - phi
%
% 输入：
%   H               : [Nx, Ny, Nc] 复信道张量
%   az_hat_deg      : 估计方位角（度）
%   el_hat_deg      : 估计俯仰角（度）
%   tau_hat_s       : 估计时延（秒）
%   Rx_ant_spacing  : 阵元间距（单位：波长）
%   B               : 总带宽
%
% 输出：
%   alpha_hat       : LS估计得到的复增益列向量

    [Nx, Ny, Nc] = size(H);

    az_hat_deg = az_hat_deg(:);
    el_hat_deg = el_hat_deg(:);
    tau_hat_s  = tau_hat_s(:);

    L_est = numel(az_hat_deg);

    if L_est == 0
        alpha_hat = [];
        return;
    end

    % ========= 1) 构造频率轴 =========
    % f = (0:Nc-1)*df
    df = B / Nc;
    f = (0:Nc-1) * df;

    % ========= 2) 构造字典矩阵 A =========
    nx = (0:Nx-1).';
    ny = (0:Ny-1);

    A = zeros(Nx * Ny * Nc, L_est);

    for l = 1:L_est
        % 由 el -> phi
        phi_l = 90 - el_hat_deg(l);

        % 对应 ux = d*sin(phi)cos(az), uy = d*sin(phi)sin(az)
        ux_l = Rx_ant_spacing * sind(phi_l) * cosd(az_hat_deg(l));
        uy_l = Rx_ant_spacing * sind(phi_l) * sind(az_hat_deg(l));

        % 空间 steering
        a_x = exp(1j * 2*pi * ux_l * nx);   % [Nx,1]
        a_y = exp(1j * 2*pi * uy_l * ny);   % [1,Ny]

        % 频率 steering
        a_f = exp(-1j * 2*pi * f * tau_hat_s(l));   % [1,Nc]

        % 3D 原子
        atom = reshape(a_x, [Nx,1,1]) .* ...
               reshape(a_y, [1,Ny,1]) .* ...
               reshape(a_f, [1,1,Nc]);

        A(:, l) = atom(:);
    end

    % ========= 3) 最小二乘估计 alpha =========
    h = H(:);
    alpha_hat = A \ h;
end