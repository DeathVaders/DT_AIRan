function H_noisy = add_noise_on_observed_entries(H_incomplete, snr_dB)
% add_noise_on_observed_entries
%   仅在已观测位置上加复高斯白噪声，支持三维信道张量 H(Nx,Ny,Nc)
%
% 输入：
%   H_incomplete : 不完整观测张量，未观测位置为 NaN
%   snr_dB       : 信噪比（dB）
%
% 输出：
%   H_noisy      : 加噪后的张量，未观测位置补 0
%

    obs_mask = ~isnan(H_incomplete);

    % 若没有任何观测点，则直接返回全零
    if ~any(obs_mask(:))
        H_noisy = zeros(size(H_incomplete));
        return;
    end

    % 已观测位置平均信号功率
    sig_pow = mean(abs(H_incomplete(obs_mask)).^2);

    % 对应噪声功率
    noise_pow = sig_pow / (10^(snr_dB/10));

    % 生成复高斯白噪声
    noise = sqrt(noise_pow/2) * ...
        (randn(size(H_incomplete)) + 1j*randn(size(H_incomplete)));

    % 只在已观测位置加噪
    H_noisy = H_incomplete;
    H_noisy(obs_mask) = H_incomplete(obs_mask) + noise(obs_mask);

    % 未观测位置补零，便于后续插值和FFT
    H_noisy(~obs_mask) = 0;
end