%% Init
clc;
clear;
rng(42);
speed = 0;
run("parameters.m");
run("material_config.m");
if SCATTERER_ENABLE
    build_scatterer_map(mapfile, SCATTERER_MAPFILE, SCATTERER_DENSITY, lat2meter, lont2meter, SCATTERER_FACE_MODE, SCATTERER_EXTRA_FACES, ...
        BUILDING_MATERIAL_NAME, GROUND_MATERIAL_NAME, LAMP_MATERIAL_NAME, VEHICLE_MATERIAL_NAME, PEDESTRIAN_MATERIAL_NAME);
    mapfile = SCATTERER_MAPFILE;
end
Nmc = 100;  % Monte Carlo samples per level
err_levels = [0.01, 0.05, 0.1, 0.15, 0.2];


save("scenario_config.mat", "BS_locs", "UE_points_by_BS");

num_bs = size(BS_locs, 1);
fprintf("Configured %d BS locations.\n", num_bs);
for bs_idx = 1:num_bs
    fprintf("  BS%d has %d UE locations.\n", bs_idx, size(UE_points_by_BS{bs_idx}, 1));
end

for bs_idx = 1:num_bs
    BS_loc = BS_locs(bs_idx, :);

    if exist("viewer", "var") && isvalid(viewer)
        viewer.clearMap();
    else
        viewer = siteviewer("Basemap", "openstreetmap", "Buildings", mapfile, "Terrain", "none");
    end
    campos(viewer, BS_loc(1) + 400 * lat2meter, BS_loc(2) + 50 * lont2meter, 300);
    camheading(viewer, 180);
    camroll(viewer, 0);

    BS = txsite("Latitude", BS_loc(1), ...
                "Longitude", BS_loc(2), ...
                "AntennaAngle", Tx_rotation, ...
                "AntennaHeight", BS_height, ...
                "TransmitterFrequency", f);

    UE_points = UE_points_by_BS{bs_idx};
    for ue_idx = 1:size(UE_points, 1)
        BS_idx = bs_idx;
        UE_idx = ue_idx;
        UE_loc = UE_points(ue_idx, :);
        fprintf("\n=== BS%d / UE%d ===\n", bs_idx, ue_idx);
        fprintf("BS loc: [%.6f, %.6f]\n", BS_loc(1), BS_loc(2));
        fprintf("UE loc: [%.6f, %.6f]\n", UE_loc(1), UE_loc(2));

        for e = 1:length(err_levels)
            err_level = err_levels(e);
            err_pct = err_level * 100;
            err_token = format_err_token(err_pct);
            fprintf(">>> Generating data for BS%d UE%d, DT error = %s%%\n", ...
                bs_idx, ue_idx, format_err_label(err_pct));
            run("generate_v2.m");

            data = struct();
            data.NMSE_samples = nmse_samples;
            data.SGCS_samples = sgcs_samples;
            data.PDP_COS_samples = pdp_cos_samples;
            data.AZ_COS_samples = az_cos_samples;
            data.EL_COS_samples = el_cos_samples;
            data.meta = struct( ...
                "speed", speed, ...
                "err_level", err_level, ...
                "err_percent", err_pct, ...
                "BS_idx", BS_idx, ...
                "BS_loc", BS_loc, ...
                "UE_idx", UE_idx, ...
                "UE_loc", UE_loc, ...
                "Nmc", Nmc, ...
                "Nerr", numel(nmse_samples) ...
            );

            filename = sprintf("v%d_err%s_BS%d_UE%d.mat", speed, err_token, BS_idx, UE_idx);
            save(filename, "data");
        end
    end
end

fprintf("Done.\n");

function token = format_err_token(err_pct)
token = format_err_label(err_pct);
token = strrep(token, ".", "p");
end

function label = format_err_label(err_pct)
label = sprintf("%.3g", err_pct);
end
