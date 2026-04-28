%% Distance + DT stacked error generation
clc;
clear;
rng(42);

speed = 0;
d_list = 0:5;                         % localization error distance in meters
% d_list = 0:2;                         % localization error distance in meters
err_levels = [0, 0.01, 0.05, 0.1, 0.15, 0.2];  % DT error ratio
% err_levels = [0, 0.01, 0.05];  % DT error ratio
Nmc = 100;                            % Monte Carlo samples per distance point

run("parameters.m");
run("material_config.m");
if SCATTERER_ENABLE
    build_scatterer_map(mapfile, SCATTERER_MAPFILE, SCATTERER_DENSITY, lat2meter, lont2meter, SCATTERER_FACE_MODE, SCATTERER_EXTRA_FACES, ...
        BUILDING_MATERIAL_NAME, GROUND_MATERIAL_NAME, LAMP_MATERIAL_NAME, VEHICLE_MATERIAL_NAME, PEDESTRIAN_MATERIAL_NAME);
    mapfile = SCATTERER_MAPFILE;
end

visualize_dir = fullfile(fileparts(pwd), "visualize");
if isempty(which("get_direction_vectors")) && isfolder(visualize_dir)
    addpath(visualize_dir);
end
[east_unit, north_unit] = get_direction_vectors();

sim_pairs = [];
for bs_idx = 1:size(BS_locs, 1)
    ue_points = UE_points_by_BS{bs_idx};
    for ue_idx = 1:size(ue_points, 1)
        sim_pairs = [sim_pairs; bs_idx, ue_idx]; 
    end
end

save("A_points.mat", "UE_points_by_BS", "UE_directions_by_BS", "BS_locs", "sim_pairs", "d_list", "err_levels", "Nmc");

if exist("viewer", "var") && isvalid(viewer)
    viewer.clearMap();
else
    viewer = siteviewer("Basemap", "openstreetmap", "Buildings", mapfile, "Terrain", "none");
end

for bs_idx = 1:size(BS_locs, 1)
    BS_idx = bs_idx;
    BS_loc = BS_locs(bs_idx, :);
    campos(viewer, BS_loc(1) + 400 * lat2meter, BS_loc(2) + 50 * lont2meter, 300);
    camheading(viewer, 180);
    campitch(viewer, -40);
    camroll(viewer, 0);

    BS = txsite("Latitude", BS_loc(1), ...
                "Longitude", BS_loc(2), ...
                "AntennaAngle", Tx_rotation, ...
                "AntennaHeight", BS_height, ...
                "TransmitterFrequency", f);

    UE_points = UE_points_by_BS{bs_idx};
    UE_directions = string(UE_directions_by_BS{bs_idx});

    for ue_idx = 1:size(UE_points, 1)
        UE_idx = ue_idx;
        UE_loc = UE_points(ue_idx, :);
        UE_direction = UE_directions(ue_idx);

        fprintf("\n=== BS%d / UE%d, dir = %s ===\n", BS_idx, UE_idx, UE_direction);
        run("distance_generate_v2.m");

        data = struct();
        data.NMSE_mean = NMSE_mean;
        data.SGCS_mean = SGCS_mean;
        data.PDP_COS_mean = PDP_COS_mean;
        data.AZ_COS_mean = AZ_COS_mean;
        data.EL_COS_mean = EL_COS_mean;
        data.meta = struct( ...
            "speed", speed, ...
            "BS_idx", BS_idx, ...
            "UE_idx", UE_idx, ...
            "BS_loc", BS_loc, ...
            "UE_loc", UE_loc, ...
            "UE_direction", UE_direction, ...
            "d_list", d_list, ...
            "err_levels", err_levels, ...
            "err_percent", err_levels * 100, ...
            "Nmc", Nmc, ...
            "distance_points_per_d", 2, ...
            "metric_rows", "DT error levels", ...
            "metric_columns", "distance error levels" ...
        );

        filename = sprintf("BS%d_UE%d_locDT.mat", BS_idx, UE_idx);
        save(filename, "data");
        fprintf("Saved %s\n", filename);
    end
end

fprintf("Done.\n");
