clc; clear;

load("A_points.mat", "sim_pairs");
d_list = 0:5;       % d = 0.1:0.1:1.0
speed  = 0;
out_dir = "figures";
if ~isfolder(out_dir)
    mkdir(out_dir);
end

num_pairs = size(sim_pairs, 1);
NMSE_Ad = zeros(num_pairs, length(d_list));
SGCS_Ad = zeros(num_pairs, length(d_list));
PDP_COS_Ad = zeros(num_pairs, length(d_list));
AZ_COS_Ad = zeros(num_pairs, length(d_list));
EL_COS_Ad = zeros(num_pairs, length(d_list));

% ===============================
% 1. 逐个 (BS, UE) 组合、逐个 d 读取 NMSE/SGCS 均值
% ===============================
for ia = 1:num_pairs
    bs_idx = sim_pairs(ia, 1);
    ue_idx = sim_pairs(ia, 2);

    for id = 1:length(d_list)
        d = d_list(id);
        d_str = strrep(sprintf("%.1f", d), '.', 'p');
        filename = sprintf("v%d_err%s_BS%dUE%d.mat", speed, d_str, bs_idx, ue_idx);
        fprintf("Loading %s\n", filename);

        if ~isfile(filename)
            warning("Missing %s, skip", filename);
            NMSE_Ad(ia, id) = NaN;
            SGCS_Ad(ia, id) = NaN;
            PDP_COS_Ad(ia, id) = NaN;
            AZ_COS_Ad(ia, id) = NaN;
            EL_COS_Ad(ia, id) = NaN;
            continue;
        end

        S = load(filename);
        if isfield(S, "data") && isfield(S.data, "NMSE_samples") && isfield(S.data, "SGCS_samples") ...
                && isfield(S.data, "PDP_COS_samples") && isfield(S.data, "AZ_COS_samples") && isfield(S.data, "EL_COS_samples")
            nmse_samples = S.data.NMSE_samples(:);
            sgcs_samples = S.data.SGCS_samples(:);
            pdp_cos_samples = S.data.PDP_COS_samples(:);
            az_cos_samples = S.data.AZ_COS_samples(:);
            el_cos_samples = S.data.EL_COS_samples(:);
            NMSE_Ad(ia, id) = mean(nmse_samples);
            SGCS_Ad(ia, id) = mean(sgcs_samples);
            PDP_COS_Ad(ia, id) = mean(pdp_cos_samples);
            AZ_COS_Ad(ia, id) = mean(az_cos_samples);
            EL_COS_Ad(ia, id) = mean(el_cos_samples);
        else
            warning("File %s has no NMSE/SGCS/PDP_COS/AZ_COS/EL_COS samples, skip", filename);
            NMSE_Ad(ia, id) = NaN;
            SGCS_Ad(ia, id) = NaN;
            PDP_COS_Ad(ia, id) = NaN;
            AZ_COS_Ad(ia, id) = NaN;
            EL_COS_Ad(ia, id) = NaN;
        end
    end
end

% ===============================
% 2. 对所有 (BS, UE) 组合做平均
% ===============================
NMSE_d_mean = mean(NMSE_Ad, 1, "omitnan");
SGCS_d_mean = mean(SGCS_Ad, 1, "omitnan");
PDP_COS_d_mean = mean(PDP_COS_Ad, 1, "omitnan");
AZ_COS_d_mean = mean(AZ_COS_Ad, 1, "omitnan");
EL_COS_d_mean = mean(EL_COS_Ad, 1, "omitnan");

disp("Average NMSE over all (BS, UE) pairs for each d:");
disp(NMSE_d_mean);
disp("Average SGCS over all (BS, UE) pairs for each d:");
disp(SGCS_d_mean);
disp("Average PDP cosine over all (BS, UE) pairs for each d:");
disp(PDP_COS_d_mean);
disp("Average azimuth cosine over all (BS, UE) pairs for each d:");
disp(AZ_COS_d_mean);
disp("Average elevation cosine over all (BS, UE) pairs for each d:");
disp(EL_COS_d_mean);

% ===============================
% 3. 绘图
% ===============================
fig1 = figure;
plot(d_list, NMSE_d_mean, '-o', 'LineWidth', 2);
grid on;
xlabel('Localization error d (m)');
ylabel('Average NMSE (averaged over all BS-UE pairs)');
title('NMSE vs d (averaged over all BS-UE pairs)');
saveas(fig1, fullfile(out_dir, "NMSE_vs_d_mean.png"));

fig2 = figure;
plot(d_list, SGCS_d_mean, '-s', 'LineWidth', 2);
grid on;
xlabel('Localization error d (m)');
ylabel('Average SGCS (averaged over all BS-UE pairs)');
title('SGCS vs d (averaged over all BS-UE pairs)');
saveas(fig2, fullfile(out_dir, "SGCS_vs_d_mean.png"));

fig3 = figure;
plot(d_list, PDP_COS_d_mean, '-^', 'LineWidth', 2);
grid on;
xlabel('Localization error d (m)');
ylabel('Average PDP cosine (averaged over all BS-UE pairs)');
title('PDP cosine vs d (averaged over all BS-UE pairs)');
saveas(fig3, fullfile(out_dir, "PDP_COS_vs_d_mean.png"));

fig4 = figure;
plot(d_list, AZ_COS_d_mean, '-d', 'LineWidth', 2);
grid on;
xlabel('Localization error d (m)');
ylabel('Average azimuth cosine (averaged over all BS-UE pairs)');
title('Azimuth cosine vs d (averaged over all BS-UE pairs)');
saveas(fig4, fullfile(out_dir, "AZ_COS_vs_d_mean.png"));

fig5 = figure;
plot(d_list, EL_COS_d_mean, '-p', 'LineWidth', 2);
grid on;
xlabel('Localization error d (m)');
ylabel('Average elevation cosine (averaged over all BS-UE pairs)');
title('Elevation cosine vs d (averaged over all BS-UE pairs)');
saveas(fig5, fullfile(out_dir, "EL_COS_vs_d_mean.png"));
