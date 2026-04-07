clc; clear;

A_list = 1:5;        % A 点编号（按你实际数量改）
d_list = (1:10) / 10;       % d = 1..10
speed  = 0;
out_dir = "figures";
if ~isfolder(out_dir)
    mkdir(out_dir);
end

NMSE_Ad = zeros(length(A_list), length(d_list));
SGCS_Ad = zeros(length(A_list), length(d_list));

% ===============================
% 1. 先算每个 (A,d) 的 NMSE/SGCS（直接读取样本）
% ===============================
for ia = 1:length(A_list)

    A = A_list(ia);

    for id = 1:length(d_list)

        d = d_list(id);
        d_str = strrep(sprintf("%.1f", d), '.', 'p');  % 0.1 → 0p1
        filename = sprintf("v%d_err%s_A%d.mat", speed, d_str, A);
        % filename = sprintf("v%d_err%d_A%d.mat", speed, d, A);
        fprintf("Loading %s\n", filename);

        if ~isfile(filename)
            warning("Missing %s, skip", filename);
            NMSE_Ad(ia, id) = NaN;
            SGCS_Ad(ia, id) = NaN;
            continue;
        end

        S = load(filename);
        if isfield(S, "data") && isfield(S.data, "NMSE_samples") && isfield(S.data, "SGCS_samples")
            nmse_samples = S.data.NMSE_samples(:);
            sgcs_samples = S.data.SGCS_samples(:);
            NMSE_Ad(ia, id) = mean(nmse_samples);
            SGCS_Ad(ia, id) = mean(sgcs_samples);
        else
            warning("File %s has no NMSE/SGCS samples, skip", filename);
            NMSE_Ad(ia, id) = NaN;
            SGCS_Ad(ia, id) = NaN;
        end

    end
end

% ===============================
% 2. 对 A 维度求平均
% ===============================
NMSE_d_mean = mean(NMSE_Ad, 1, "omitnan");   % [1 x Nd]
SGCS_d_mean = mean(SGCS_Ad, 1, "omitnan");   % [1 x Nd]

disp("Average NMSE over A points for each d:");
disp(NMSE_d_mean);
disp("Average SGCS over A points for each d:");
disp(SGCS_d_mean);

% ===============================
% 3. 画图并保存
% ===============================
fig1 = figure;
plot(d_list, NMSE_d_mean, '-o', 'LineWidth', 2);
grid on;
xlabel('Localization error d (m)');
ylabel('Average NMSE (averaged over UE locations)');
title('NMSE vs d (averaged over UE locations)');
saveas(fig1, fullfile(out_dir, "NMSE_vs_d_mean.png"));

fig2 = figure;
plot(d_list, SGCS_d_mean, '-s', 'LineWidth', 2);
grid on;
xlabel('Localization error d (m)');
ylabel('Average SGCS (averaged over UE locations)');
title('SGCS vs d (averaged over UE locations)');
saveas(fig2, fullfile(out_dir, "SGCS_vs_d_mean.png"));
