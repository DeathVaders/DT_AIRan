%% Init
clc;
clear;

speed = 0;
run("parameters.m");

% DT construction error levels (relative)
% err_levels = [0.001, 0.002, 0.003, 0.004, 0.005, 0.006, 0.007, 0.008, 0.009, 0.01,...
%     0.011, 0.012, 0.013, 0.014, 0.015, 0.016, 0.017, 0.018, 0.019, 0.02];
Nmc = 100;  % Monte Carlo samples per level
err_levels = [0.01, 0.05, 0.1, 0.15, 0.2];
% Fix random seed for reproducibility
rng(42);

%% A points (UE locations)
A_points = [
    39.906535   116.403688
    39.907557   116.402229
    39.906371   116.400752
    39.905354   116.402234
    39.906372   116.403340
];
% A_points = [
%     39.906310   116.405150
%     39.906327   116.404960
%     39.906566   116.405164
%     39.906338   116.405170
% ];

disp(A_points);
save("A_points.mat", "A_points");
%% Site Viewer
if exist('viewer', 'var') && isvalid(viewer)
    viewer.clearMap();
else
    viewer = siteviewer("Basemap", "openstreetmap", "Buildings", mapfile);
    campos(viewer, BS_loc(1) + 400 * lat2meter, BS_loc(2) + 50 * lont2meter, 300);
    camheading(viewer, 180);
    camroll(viewer, 0);
end

%% Base station site
BS = txsite("Latitude", BS_loc(1), ...
            "Longitude", BS_loc(2), ...
            "AntennaAngle", Tx_rotation, ...
            "AntennaHeight", BS_height, ...
            "TransmitterFrequency", f);

%% Generate data
load("A_points.mat", "A_points");

for a = 1:size(A_points, 1)
    UE_loc = A_points(a, :);

    for e = 1:length(err_levels)
        err_level = err_levels(e);
        err_pct = err_level * 100;
        err_token = format_err_token(err_pct);
        fprintf(">>> Generating data for DT error = %s%%\n", format_err_label(err_pct));
        run("generate_v2.m");

        data = struct();
        data.NMSE_samples = nmse_samples;
        data.SGCS_samples = sgcs_samples;
        data.meta = struct( ...
            "speed", speed, ...
            "err_level", err_level, ...
            "err_percent", err_pct, ...
            "A_idx", a, ...
            "A_loc", UE_loc, ...
            "Nmc", Nmc, ...
            "Nerr", numel(nmse_samples) ...
        );

        filename = sprintf("v%d_err%s_A%d.mat", speed, err_token, a);
        save(filename, "data");
    end
end

fprintf("Done. Last file: %s\n", filename);

function token = format_err_token(err_pct)
token = format_err_label(err_pct);
token = strrep(token, ".", "p");
end

function label = format_err_label(err_pct)
label = sprintf("%.3g", err_pct);
end
