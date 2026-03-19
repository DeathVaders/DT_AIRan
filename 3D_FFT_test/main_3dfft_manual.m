%% main_3dfft_manual.m
% 手动数据库主流程
% 真值参数 -> 构建信道 -> 导频抽样 -> 加噪 -> 插值 -> 3DFFT恢复 -> 指标统计

clc;
clear;

% 读取系统参数
run("parameters.m");

% 若手动数据库不存在，则先生成
if ~isfile("RTDB_manual_5groups.mat")
    fprintf("RTDB_manual_5groups.mat not found. Generate manual RTDB first...\n");
    run("step1_save_manual_db.m");
end

% 加载手动数据库
load("RTDB_manual_5groups.mat", "RTDB");

% 仿真设置
snr_dB_list = 20:1:50;
numPilots = round(1 * Nc);
pilots = round(linspace(1, Nc, numPilots));
pilots = unique(pilots);

OS_x = 1;
OS_y = 1;
OS_delay = 1;

RESULT = struct();

fprintf("========== Start 3D-FFT with manual RTDB ==========\n");

for a = 1:length(RTDB)
    fprintf("\n>>> Process group %d/%d\n", a, length(RTDB));

    % 当前组真值参数
    rt_true = RTDB(a).true;
    az_true = rt_true.AoA_az(:);
    el_true = rt_true.AoA_el(:);
    tau_true = rt_true.ToA(:);
    alpha_true = rt_true.alpha(:);

    % 构建真实信道
    H_true = build_channel_from_rt(rt_true, UE_Rx, Rx_ant_spacing, Nc, Ts);

    % 导频抽样
    H_incomplete = nan(size(H_true));
    H_incomplete(:, :, pilots) = H_true(:, :, pilots);

    % 保存基础信息
    RESULT(a).A_index = a;
    RESULT(a).rt_true = rt_true;
    RESULT(a).pilots = pilots;
    RESULT(a).H_true = H_true;
    RESULT(a).H_incomplete = H_incomplete;

    for is = 1:length(snr_dB_list)
        snr_dB = snr_dB_list(is);
        fprintf("    -> SNR = %d dB\n", snr_dB);

        W_mc = zeros(numMC, 1);
        theta_mse_mc = zeros(numMC, 1);
        phi_mse_mc = zeros(numMC, 1);
        tau_mse_mc = zeros(numMC, 1);
        alpha_nmse_mc = zeros(numMC, 1);

        for imc = 1:numMC
            % 加噪
            H_noisy = add_noise_on_observed_entries(H_incomplete, snr_dB);

            % 插值
            H_interp = local_interp_channel(H_noisy, pilots, Nc);

            % 3DFFT 参数恢复
            num_peaks = max(1, numel(alpha_true));
            est = estimate_params_3dfft( ...
                H_interp, Rx_ant_spacing, B, ...
                OS_x, OS_y, OS_delay, num_peaks);

            % Wasserstein distance
            [W, pairs] = joint_wasserstein_optimal_3d( ...
                az_true, el_true, tau_true, alpha_true, ...
                est.az, est.el, est.tau, est.alpha);
            W_mc(imc) = W;

            % 根据最优匹配计算误差
            idx_t = pairs(:, 1);
            idx_e = pairs(:, 2);

            az_t = az_true(idx_t);
            az_e = est.az(idx_e);
            el_t = el_true(idx_t);
            el_e = est.el(idx_e);
            tau_t = tau_true(idx_t);
            tau_e = est.tau(idx_e);
            alpha_t = alpha_true(idx_t);
            alpha_e = est.alpha(idx_e);

            dtheta = mod((az_e - az_t) + 180, 360) - 180;
            dphi = el_e - el_t;
            dtau = tau_e - tau_t;

            theta_mse_mc(imc) = mean(dtheta .^ 2);
            phi_mse_mc(imc) = mean(dphi .^ 2);
            tau_mse_mc(imc) = mean(dtau .^ 2);
            alpha_nmse_mc(imc) = sum(abs(alpha_e - alpha_t) .^ 2) / ...
                max(sum(abs(alpha_t) .^ 2), 1e-12);

            % 保存一个示例，便于后续检查
            if imc == 1
                RESULT(a).snr(is).H_noisy_example = H_noisy;
                RESULT(a).snr(is).H_interp_example = H_interp;
                RESULT(a).snr(is).est_example = est;
                RESULT(a).snr(is).pairs_example = pairs;
            end
        end

        % Monte Carlo 平均结果
        RESULT(a).snr(is).snr_dB = snr_dB;
        RESULT(a).snr(is).W = mean(W_mc, "omitnan");
        RESULT(a).snr(is).theta_rmse = sqrt(mean(theta_mse_mc, "omitnan"));
        RESULT(a).snr(is).phi_rmse = sqrt(mean(phi_mse_mc, "omitnan"));
        RESULT(a).snr(is).tau_rmse = sqrt(mean(tau_mse_mc, "omitnan"));
        RESULT(a).snr(is).alpha_nmse = mean(alpha_nmse_mc, "omitnan");
    end
end

% 保存结果
save("RESULT_3DFFT_manual.mat", "RESULT", "-v7.3");

fprintf("\n========== Simulation finished ==========\n");
fprintf("Saved result: RESULT_3DFFT_manual.mat\n");

function H_interp = local_interp_channel(H_noisy, pilots, Nc)
% 对缺失子载波做逐天线线性插值

    [Nx, Ny, ~] = size(H_noisy);
    H_interp = zeros(size(H_noisy));
    xq = 1:Nc;

    for ix = 1:Nx
        for iy = 1:Ny
            y_obs = squeeze(H_noisy(ix, iy, pilots));

            if numel(pilots) < 2
                H_interp(ix, iy, :) = H_noisy(ix, iy, :);
            else
                y_interp = interp1(pilots, y_obs, xq, "linear", "extrap");
                H_interp(ix, iy, :) = reshape(y_interp, 1, 1, []);
            end
        end
    end
end
