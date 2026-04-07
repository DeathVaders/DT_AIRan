fprintf("    Using localization error d = %d m\n", d);

pm = propagationModel("raytracing");
pm.AngularSeparation = "low";
pm.MaxNumReflections = MaxNumReflections;
pm.MaxRelativePathLoss = MaxRelativePathLoss;
pm.MaxNumDiffractions = MaxNumDiffractions;

theta_list = 0:0.5:359.5;
Nerr = numel(theta_list);
nmse_samples = zeros(Nerr, 1);
sgcs_samples = zeros(Nerr, 1);

[mx, my] = ndgrid(0:Nx-1, 0:Ny-1);

build_channel = @(ray_cell) local_build_channel(ray_cell, mx, my, Rx_ant_spacing, f_k, Nc, max_paths);

UE_loc_true = UE_loc;
UE_true = rxsite("Latitude", UE_loc_true(1), "Longitude", UE_loc_true(2), ...
                 "AntennaHeight", UE_height, "AntennaAngle", Rx_rotation);
rays_true = raytrace(BS, UE_true, pm);
if a == 1 && d == d_list(1)
    if isempty(rays_true) || isempty(rays_true{1})
        fprintf("A点1: 无路径\n");
    else
        fprintf("A点1: 路径数 = %d\n", length(rays_true{1}));
    end
end
H_ref = build_channel(rays_true);

vec_ref = H_ref(:);
den = sum(abs(vec_ref).^2);
norm_ref_sq = den;

for k = 1:Nerr
    theta = theta_list(k) * pi / 180;
    dx = d * cos(theta);
    dy = d * sin(theta);

    UE_loc_use = UE_loc_true;
    UE_loc_use(1) = UE_loc_true(1) + dy * lat2meter;
    UE_loc_use(2) = UE_loc_true(2) + dx * lont2meter;

    UE = rxsite("Latitude", UE_loc_use(1), "Longitude", UE_loc_use(2), ...
                "AntennaHeight", UE_height, "AntennaAngle", Rx_rotation);
    rays = raytrace(BS, UE, pm);
    H_err = build_channel(rays);

    diff_t = H_err - H_ref;
    num = sum(abs(diff_t(:)).^2);
    vec_k = H_err(:);
    norm_k_sq = sum(abs(vec_k).^2);
    dot_ref_k = sum(conj(vec_ref) .* vec_k);

    if den == 0
        nmse_samples(k) = 0;
    else
        nmse_samples(k) = num / den;
    end

    if norm_ref_sq == 0 || norm_k_sq == 0
        sgcs_samples(k) = 0;
    else
        sgcs_samples(k) = abs(dot_ref_k)^2 / (norm_ref_sq * norm_k_sq);
    end
end

fprintf("    Finished d = %d m with %d error samples.\n", d, Nerr);

function H_out = local_build_channel(ray_cell, mx, my, Rx_ant_spacing, f_k, Nc, max_paths)
H_out = zeros(size(mx, 1), size(mx, 2), Nc);

if isempty(ray_cell) || isempty(ray_cell{1})
    return;
end

N_use = min(length(ray_cell{1}), max_paths);
rays_used = ray_cell{1}(1:N_use);
pathAoAs = [rays_used.AngleOfArrival];
theta = pathAoAs(1, :);
elev = pathAoAs(2, :);
power_dB = -[rays_used.PathLoss];
ToAs = [rays_used.PropagationDelay];
phases = [rays_used.PhaseShift];
power = 1e-3 * (10.^(0.1 * (power_dB + 30)));

for l = 1:N_use
    rx_response_l = exp(1j * 2 * pi * Rx_ant_spacing * ...
        (mx * cosd(elev(l)) * cosd(theta(l)) + ...
         my * cosd(elev(l)) * sind(theta(l))));
    freq_response_l = exp(-1j * 2 * pi * f_k * ToAs(l));
    alpha_l = sqrt(power(l) / Nc) * exp(1j * phases(l));
    H_out = H_out + alpha_l .* rx_response_l .* reshape(freq_response_l, 1, 1, Nc);
end
end