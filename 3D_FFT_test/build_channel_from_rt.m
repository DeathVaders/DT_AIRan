function H = build_channel_from_rt(rt, UE_Rx, Rx_ant_spacing, Nc, Ts)
% build_channel_from_rt

%   根据某个位置点保存的 ray tracing 参数 rt，重建三维频域信道 H
%
% 输入：
%   rt              : 单个点的参数结构体（来自 RTDB(a).true 或 RTDB(a).err(id).points(it)）
%   UE_Rx           : 接收阵列维度，例如 [8,4]
%   Rx_ant_spacing  : 阵元间距（单位：波长）
%   Nc              : 子载波数
%   Ts              : 采样周期（1/B）
%
% 输出：
%   H               : 大小为 [Nx, Ny, Nc] 的频域信道张量
%
% 说明：
%   这里不再把二维接收阵列压平。
%   若 UE_Rx = [8,4]，则输出 H 的大小就是 [8,4,64]。
%
%   建模公式：
%       H(nx, ny, k) = sum_l alpha_l *
%                      exp(j*2*pi*d*(nx*u_x + ny*u_y)) *
%                      exp(-j*2*pi*(k/Nc)*tau_l/Ts) / sqrt(Nc)

    Nx = UE_Rx(1);
    Ny = UE_Rx(2);

    % 若无路径，则返回全零张量
    if ~rt.has_rays || rt.numRays == 0
        H = zeros(Nx, Ny, Nc);
        return;
    end

    % ===== 1. 提取路径参数 =====
    DoA_theta = rt.AoA_az(:).';      % 方位角，1 x L
    DoA_phi   = 90 - rt.AoA_el(:).'; % 倾角，1 x L
    ToA       = rt.ToA(:).';         % 1 x L
    alpha     = rt.alpha(:).';       % 1 x L

    L = numel(ToA);

    % ===== 2. 构造二维接收阵列索引 =====
    % x方向索引：0 ~ Nx-1
    % y方向索引：0 ~ Ny-1
    x_idx = (0:Nx-1).';   % Nx x 1
    y_idx = (0:Ny-1).';   % Ny x 1

    % ===== 3. 根据 AoA 计算二维空间频率 =====
    % gamma_RX = j*2*pi*d*[sin(phi)cos(theta); sin(phi)sin(theta); cos(phi)]
    %
    % 对于平面阵列，这里只需要前两个方向分量：
    ux = Rx_ant_spacing * sind(DoA_phi) .* cosd(DoA_theta);   % 1 x L
    uy = Rx_ant_spacing * sind(DoA_phi) .* sind(DoA_theta);   % 1 x L

    % ===== 4. 构造二维阵列响应 =====
    % ax: [Nx x L]
    % ay: [Ny x L]
    ax = exp(1j * 2*pi * (x_idx * ux));
    ay = exp(1j * 2*pi * (y_idx * uy));

    % ===== 5. 构造子载波频域响应 =====
    % 子载波索引 0 ~ Nc-1
    k_idx = (0:Nc-1).';   % Nc x 1

    % freq_resp: [Nc x L]
    freq_resp = exp(-1j * 2*pi * (k_idx / Nc) * (ToA / Ts));

    % 把基础复增益 alpha 乘进去，并做 1/sqrt(Nc) 归一化
    path_const = freq_resp .* alpha / sqrt(Nc);   % [Nc x L]

    % ===== 6. 多径叠加，构造 H(Nx, Ny, Nc) =====
    H = zeros(Nx, Ny, Nc);

    for l = 1:L
        % 单条路径的二维空间响应：Nx x Ny
        Axy = ax(:,l) * ay(:,l).';

        % 单条路径在所有子载波上的响应：1 x 1 x Nc
        fk = reshape(path_const(:,l), 1, 1, Nc);

        % 外积叠加
        H = H + Axy .* fk;
    end
end