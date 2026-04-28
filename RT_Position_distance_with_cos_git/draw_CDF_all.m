clc; clear;

load("A_points.mat", "sim_pairs");
d_list = 0:10;
speed  = 0;
out_dir = "figures";
if ~isfolder(out_dir)
    mkdir(out_dir);
end

num_pairs = size(sim_pairs, 1);
NMSE_samples_allA = cell(length(d_list), 1);
SGCS_samples_allA = cell(length(d_list), 1);
for id = 1:length(d_list)
    d = d_list(id);
    fprintf("Processing d = %.1f m\n", d);

    nmse_pool = [];
    sgcs_pool = [];
    for ia = 1:num_pairs
        bs_idx = sim_pairs(ia, 1);
        ue_idx = sim_pairs(ia, 2);
        d_str = strrep(sprintf("%.1f", d), '.', 'p');
        filename = sprintf("v%d_err%s_BS%dUE%d.mat", speed, d_str, bs_idx, ue_idx);

        if ~isfile(filename)
            warning("Missing %s, skip", filename);
            continue;
        end

        S = load(filename);
        if isfield(S, "data") && isfield(S.data, "NMSE_samples") && isfield(S.data, "SGCS_samples")
            nmse_pool = [nmse_pool; S.data.NMSE_samples(:)]; 
            sgcs_pool = [sgcs_pool; S.data.SGCS_samples(:)]; 
        else
            warning("File %s has no NMSE/SGCS samples, skip", filename);
            continue;
        end
    end

    NMSE_samples_allA{id} = nmse_pool;
    SGCS_samples_allA{id} = sgcs_pool;
end

colors = [
    0.1216 0.4667 0.7059;
    1.0000 0.4980 0.0549;
    0.1725 0.6275 0.1725;
    0.8392 0.1529 0.1569;
    0.5804 0.4039 0.7412;
    0.5490 0.3373 0.2941;
    0.8902 0.4667 0.7608;
    0.4980 0.4980 0.4980;
    0.7373 0.7412 0.1333;
    0.0902 0.7451 0.8118;
    0 0 0
];

fig1 = figure; hold on;
for id = 1:length(d_list)
    [f, x] = ecdf(NMSE_samples_allA{id});
    plot(x, f, 'LineWidth', 2, ...
         'Color', colors(id,:), ...
         'DisplayName', sprintf('d = %.1f m', d_list(id)));
end

grid on;
xlabel('NMSE');
ylabel('CDF');
title('CDF of NMSE (All BS-UE pairs combined)');
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
title('CDF of SGCS (All BS-UE pairs combined)');
legend show;
saveas(fig2, fullfile(out_dir, "CDF_AllA_SGCS.png"));
