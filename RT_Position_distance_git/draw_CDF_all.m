clc; clear;

d_list = (1:10) / 10;
A_list = 1:5;      % 假设 x 为 Point A
speed  = 0;
out_dir = "figures";
if ~isfolder(out_dir)
    mkdir(out_dir);
end

NMSE_samples_allA = cell(length(d_list),1);
SGCS_samples_allA = cell(length(d_list),1);
for id = 1:length(d_list)

    d = d_list(id);
    fprintf("Processing d = %d m\n", d);

    nmse_pool = [];   % 这个 d 的全 A 样本池
    sgcs_pool = [];
    for ia = 1:length(A_list)

        A = A_list(ia);
        d_str = strrep(sprintf("%.1f", d), '.', 'p');  % 0.1 → 0p1
        filename = sprintf("v%d_err%s_A%d.mat", speed, d_str, A);
        % filename = sprintf("v%d_err%d_A%d.mat", speed, d, A);

        if ~isfile(filename)
            warning("Missing %s, skip", filename);
            continue;
        end

        S = load(filename);
        if isfield(S, "data") && isfield(S.data, "NMSE_samples") && isfield(S.data, "SGCS_samples")
            nmse_pool = [nmse_pool; S.data.NMSE_samples(:)]; %#ok<AGROW>
            sgcs_pool = [sgcs_pool; S.data.SGCS_samples(:)]; %#ok<AGROW>
        else
            warning("File %s has no NMSE/SGCS samples, skip", filename);
            continue;
        end
    end

    NMSE_samples_allA{id} = nmse_pool;
    SGCS_samples_allA{id} = sgcs_pool;
end
colors = [
    0.1216 0.4667 0.7059;   % 蓝
    1.0000 0.4980 0.0549;   % 橙
    0.1725 0.6275 0.1725;   % 绿
    0.8392 0.1529 0.1569;   % 红
    0.5804 0.4039 0.7412;   % 紫
    0.5490 0.3373 0.2941;   % 棕
    0.8902 0.4667 0.7608;   % 粉
    0.4980 0.4980 0.4980;   % 灰
    0.7373 0.7412 0.1333;   % 黄绿
    0.0902 0.7451 0.8118;   % 青
];
fig1 = figure; hold on;
%colors = lines(length(d_list));

for id = 1:length(d_list)
    [f, x] = ecdf(NMSE_samples_allA{id});
    plot(x, f, 'LineWidth', 2, ...
         'Color', colors(id,:), ...
         'DisplayName', sprintf('d = %.1f m', d_list(id)));
end

grid on;
xlabel('NMSE');
ylabel('CDF');
title('CDF of NMSE (All Point A combined)');
legend show;
saveas(fig1, fullfile(out_dir, "CDF_AllA_NMSE.png"));

fig2 = figure; hold on;

for id = 1:length(d_list)
    [f, x] = ecdf(SGCS_samples_allA{id});
    plot(x, f, 'LineWidth', 2, ...
         'Color', colors(id,:), ...
         'DisplayName', sprintf('d = %.1f m', d_list(id)));
end

grid on;
xlabel('SGCS');
ylabel('CDF');
title('CDF of SGCS (All Point A combined)');
legend show;
saveas(fig2, fullfile(out_dir, "CDF_AllA_SGCS.png"));
