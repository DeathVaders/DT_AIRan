%% main_3dfft.m
%   1. 若参数数据库不存在，则先建立 RTDB
%   2. 读取 RTDB
%   3. 用真实点与误差点参数分别构建 H(Nx,Ny,Nc)
%   4. 加导频，形成 H_incomplete
%   5. 在观测位置加噪（Monte Carlo）
%   6. 沿子载波维线性插值
%   7. 3D-FFT 恢复 azimuth / elevation / tau
%   8. 计算与真实参数之间的联合 Wasserstein 距离
%
% 输出：
%   RESULT_3DFFT_Wasserstein.mat

clc;
clear;

%% 读取系统参数
run("parameters.m");

%% 若参数数据库不存在，则先生成
if ~isfile("RTDB_5points_circle.mat")
    fprintf("未找到 RTDB_5points_circle.mat，开始建立参数数据库...\n");
    run("step1_save_raytracing_db.m");
end

%% 读取参数数据库
load("RTDB_5points_circle.mat", "RTDB");

%% 实验设置
d_list = 1:10;
snr_dB_list = -30:5:0;

% 导频设置：子载波维稀疏采样
%pilot_step = 2;
%pilots = 1:pilot_step:Nc;

numPilots = round(0.4*Nc);
pilots = round(linspace(1,Nc,numPilots));
pilots = unique(pilots);

% 3D-FFT过采样参数
OS_x = 4;
OS_y = 4;
OS_delay = 4;

RESULT = struct();

fprintf("========== 开始 3D-FFT 主流程 ==========\n");

for a = 1:length(RTDB)
    fprintf("\n>>> 处理第 %d/%d 个真实点\n", a, length(RTDB));

    %% ===== 1) 真实点参数 =====
    rt_true = RTDB(a).true;

    H_true = build_channel_from_rt(rt_true, UE_Rx, Rx_ant_spacing, Nc, Ts);

    RESULT(a).A_index = a;
    RESULT(a).rt_true = rt_true;
    RESULT(a).H_true = H_true;

    % 真实路径参数
    az_true = rt_true.AoA_az(:);
    el_true = rt_true.AoA_el(:);
    tau_true = rt_true.ToA(:);
    alpha_true = rt_true.alpha(:);

    for id = 1:length(d_list)
        d = d_list(id);
        fprintf("    -> 误差半径 d = %d m\n", d);

        RESULT(a).err(id).d = d;

        for it = 1:length(RTDB(a).err(id).points)
            rt_err = RTDB(a).err(id).points(it);

            RESULT(a).err(id).points(it).theta_deg = rt_err.theta_deg;
            RESULT(a).err(id).points(it).loc = rt_err.loc;
            RESULT(a).err(id).points(it).has_rays = rt_err.has_rays;

            %% ===== 2) 用误差点参数重建 H(Nx,Ny,Nc) =====
            H_err = build_channel_from_rt(rt_err, UE_Rx, Rx_ant_spacing, Nc, Ts);
            RESULT(a).err(id).points(it).H = H_err;

            %% ===== 3) 导频抽样：只在子载波维保留部分位置 =====
            H_incomplete = nan(size(H_err));    % [Nx, Ny, Nc]
            H_incomplete(:,:,pilots) = H_err(:,:,pilots);
            RESULT(a).err(id).points(it).H_incomplete = H_incomplete;

            for is = 1:length(snr_dB_list)
                snr_dB = snr_dB_list(is);

                % 每个 SNR 下做 numMC 次噪声实验
                W_mc = zeros(numMC,1);
                theta_mse_mc   = zeros(numMC,1);
                phi_mse_mc     = zeros(numMC,1);
                tau_mse_mc     = zeros(numMC,1);
                alpha_nmse_mc  = zeros(numMC,1);

                for imc = 1:numMC

                    %% ===== 4) 在已观测位置加噪 =====
                    H_noisy = add_noise_on_observed_entries(H_incomplete, snr_dB);

                    %% ===== 5) 沿子载波维做线性插值 =====
                    [Nx, Ny, ~] = size(H_noisy);
                    H_interp = zeros(size(H_noisy));
                    xq = 1:Nc;

                    for ix = 1:Nx
                        for iy = 1:Ny
                            y_obs = squeeze(H_noisy(ix, iy, pilots));

                            if numel(pilots) < 2
                                H_interp(ix, iy, :) = H_noisy(ix, iy, :);
                            else
                                tmp = interp1(pilots, y_obs, xq, 'linear', 'extrap');
                                H_interp(ix, iy, :) = reshape(tmp, 1, 1, []);
                            end
                        end
                    end

                    %% ===== 6) 3D-FFT 参数恢复 =====
                    num_peaks = max(1, numel(az_true));

                    est = estimate_params_3dfft( ...
                        H_interp, Rx_ant_spacing, B, ...
                        OS_x, OS_y, OS_delay, num_peaks);
                    % ===== 调试：打印真实和估计 delay =====
                    if imc == 1 && it == 1 && a == 1 && id == 1
                        fprintf("\n==== Delay Debug ====\n");
                        fprintf("True tau (ns):\n");
                        disp(tau_true(:)'*1e9);
                    
                        fprintf("Estimated tau (ns):\n");
                        disp(est.tau(:)'*1e9);
                        fprintf("True alpha :\n");
                        disp(alpha_true(:)');
                    
                        fprintf("Estimated alpha:\n");
                        disp(est.alpha(:)');
                        fprintf("PathLoss (dB):\n");
                        disp(rt_true.PathLoss(:)');
                        
                        fprintf("|alpha|:\n");
                        disp(abs(rt_true.alpha(:))');
                        
                        fprintf("True tau (ns):\n");
                        disp(tau_true(:)' * 1e9);
                        
                        fprintf("Estimated tau (ns):\n");
                        disp(est.tau(:)' * 1e9);
                        
                        fprintf("Delay resolution = %.2f ns\n", 1/B * 1e9);
                        fprintf("Delay max range = %.2f ns\n", (Nc/B) * 1e9);
                    end
                    %% ===== 7) 计算联合 Wasserstein 距离 =====
                    %W = joint_wasserstein_greedy_3d( ...
                    %    az_true, el_true, tau_true, alpha_true, ...
                    %    est.az, est.el, est.tau, est.alpha);
                    [W, pairs] = joint_wasserstein_optimal_3d( ...
                        az_true, el_true, tau_true, alpha_true, ...
                        est.az, est.el, est.tau, est.alpha);

                    W_mc(imc) = W;
                    %% ===== 8) 基于同一组 pairs 计算四个参数误差 =====
                    idx_t = pairs(:,1);
                    idx_e = pairs(:,2);
            
                    az_t = az_true(idx_t);
                    az_e = est.az(idx_e);
            
                    el_t = el_true(idx_t);
                    el_e = est.el(idx_e);
            
                    tau_t = tau_true(idx_t);
                    tau_e = est.tau(idx_e);
            
                    alpha_t = alpha_true(idx_t);
                    alpha_e = est.alpha(idx_e);
            
                    % theta：方位角，周期性处理
                    dtheta = mod((az_e - az_t) + 180, 360) - 180;
            
                    % phi：俯仰角
                    dphi = el_e - el_t;
            
                    % tau：时延
                    dtau = tau_e - tau_t;
            
                    % alpha：如果你想和当前代价函数一致，就比较幅值
                    alpha_num = sum((abs(alpha_e) - abs(alpha_t)).^2);
                    alpha_den = sum(abs(alpha_t).^2);
            
                    theta_mse_mc(imc)  = mean(dtheta.^2);
                    phi_mse_mc(imc)    = mean(dphi.^2);
                    tau_mse_mc(imc)    = mean(dtau.^2);
                    alpha_nmse_mc(imc) = alpha_num / max(alpha_den, 1e-12);
            
                    %% 如果你想比较复数 alpha，而不是幅值，把上面 alpha 那两行改成：
                    % alpha_num = sum(abs(alpha_e - alpha_t).^2);
                    % alpha_den = sum(abs(alpha_t).^2);
                    % alpha_nmse_mc(imc) = alpha_num / max(alpha_den, 1e-12);
            
                    %% ===== 8) 保存单次 MC 结果 =====
                    %RESULT(a).err(id).points(it).snr(is).MC(imc).snr_dB = snr_dB;
                    %RESULT(a).err(id).points(it).snr(is).MC(imc).mc_index = imc;
                    %RESULT(a).err(id).points(it).snr(is).MC(imc).H_noisy = H_noisy;
                    %RESULT(a).err(id).points(it).snr(is).MC(imc).H_interp = H_interp;
                    %RESULT(a).err(id).points(it).snr(is).MC(imc).est = est;
                    %RESULT(a).err(id).points(it).snr(is).MC(imc).W = W;
                end
                W_mean = mean(W_mc);
                theta_rmse  = sqrt(mean(theta_mse_mc, 'omitnan'));
                phi_rmse    = sqrt(mean(phi_mse_mc, 'omitnan'));
                tau_rmse    = sqrt(mean(tau_mse_mc, 'omitnan'));
                alpha_nmse  = mean(alpha_nmse_mc, 'omitnan');
                %% ===== 9) 保存该 SNR 下的统计量 =====
                RESULT(a).err(id).points(it).snr(is).snr_dB = snr_dB;
                RESULT(a).err(id).points(it).snr(is).W = W_mean;
                RESULT(a).err(id).points(it).snr(is).theta_rmse  = theta_rmse;
                RESULT(a).err(id).points(it).snr(is).phi_rmse    = phi_rmse;
                RESULT(a).err(id).points(it).snr(is).tau_rmse    = tau_rmse;
                RESULT(a).err(id).points(it).snr(is).alpha_nmse  = alpha_nmse;
            end
        end
    end
end

save("RESULT_3DFFT_Wasserstein.mat", "RESULT", "-v7.3");

fprintf("\n========== 全部完成 ==========\n");
fprintf("结果文件：RESULT_3DFFT_Wasserstein.mat\n");