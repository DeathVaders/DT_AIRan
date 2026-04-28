fprintf("    Using street-direction localization error d = %.1f m\n", d);

pm = propagationModel("raytracing");
pm.AngularSeparation = "low";
pm.MaxNumReflections = MaxNumReflections;
pm.MaxRelativePathLoss = MaxRelativePathLoss;
pm.MaxNumDiffractions = MaxNumDiffractions;

nmse_samples = zeros(2, 1);
sgcs_samples = zeros(2, 1);
pdp_cos_samples = zeros(2, 1);
az_cos_samples = zeros(2, 1);
el_cos_samples = zeros(2, 1);
err_points = zeros(2, 2);

[mx, my] = ndgrid(0:Nx-1, 0:Ny-1);

build_channel = @(ray_cell) local_build_channel(ray_cell, mx, my, Rx_ant_spacing, f_k, Nc);
build_pdp = @(ray_cell) local_build_pdp(ray_cell, PDP_delay_grid_s);
build_az_spectrum = @(ray_cell) local_build_angle_spectrum(ray_cell, AZ_angle_grid_deg, false);
build_el_spectrum = @(ray_cell) local_build_angle_spectrum(ray_cell, EL_angle_grid_deg, true);

UE_loc_true = UE_loc;
UE_true = rxsite("Latitude", UE_loc_true(1), "Longitude", UE_loc_true(2), ...
                 "AntennaHeight", UE_height, "AntennaAngle", Rx_rotation);
rays_true = raytrace(BS, UE_true, pm);
if ue_idx == 1 && d == d_list(1)
    if isempty(rays_true) || isempty(rays_true{1})
        fprintf("BS%d UE%d: no ray found.\n", bs_idx, ue_idx);
    else
        fprintf("BS%d UE%d: path count = %d\n", bs_idx, ue_idx, length(rays_true{1}));
    end
end
H_ref = build_channel(rays_true);
PDP_ref = build_pdp(rays_true);
AZ_ref = build_az_spectrum(rays_true);
EL_ref = build_el_spectrum(rays_true);

vec_ref = H_ref(:);
den = sum(abs(vec_ref).^2);
norm_ref_sq = den;

if UE_direction == "EW"
    street_unit = east_unit;
elseif UE_direction == "NS"
    street_unit = north_unit;
else
    error("Unsupported UE_direction: %s. Only 'EW' or 'NS' are allowed.", UE_direction);
end

offsets = [-1; 1] * d;
for k = 1:2
    offset = offsets(k);
    UE_loc_use = UE_loc_true + offset * street_unit;
    err_points(k, :) = UE_loc_use;

    UE = rxsite("Latitude", UE_loc_use(1), "Longitude", UE_loc_use(2), ...
                "AntennaHeight", UE_height, "AntennaAngle", Rx_rotation);
    rays = raytrace(BS, UE, pm);
    H_err = build_channel(rays);
    PDP_err = build_pdp(rays);
    AZ_err = build_az_spectrum(rays);
    EL_err = build_el_spectrum(rays);

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

    pdp_cos_samples(k) = local_cosine_similarity(PDP_ref, PDP_err);
    az_cos_samples(k) = local_cosine_similarity(AZ_ref, AZ_err);
    el_cos_samples(k) = local_cosine_similarity(EL_ref, EL_err);
end

fprintf("    Finished BS%d UE%d, dir = %s, d = %.1f m with %d street-direction samples.\n", ...
    bs_idx, ue_idx, UE_direction, d, numel(nmse_samples));

function H_out = local_build_channel(ray_cell, mx, my, Rx_ant_spacing, f_k, Nc)
H_out = zeros(size(mx, 1), size(mx, 2), Nc);

if isempty(ray_cell) || isempty(ray_cell{1})
    return;
end

N_use = length(ray_cell{1});
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

function pdp_out = local_build_pdp(ray_cell, delay_grid_s)
pdp_out = zeros(numel(delay_grid_s), 1);

if isempty(ray_cell) || isempty(ray_cell{1})
    return;
end

rays_used = ray_cell{1};
ToAs = [rays_used.PropagationDelay];
ToAs_use = ToAs - min(ToAs);%%修改为相对时延
power_dB = -[rays_used.PathLoss];
power = 1e-3 * (10.^(0.1 * (power_dB + 30)));

for l = 1:numel(ToAs_use)
    delay_l = ToAs_use(l);
    power_l = power(l);

    if delay_l <= delay_grid_s(1)
        pdp_out(1) = pdp_out(1) + power_l;
        continue;
    end

    if delay_l >= delay_grid_s(end)
        pdp_out(end) = pdp_out(end) + power_l;
        continue;
    end

    right_idx = find(delay_grid_s >= delay_l, 1, "first");
    left_idx = right_idx - 1;
    left_delay = delay_grid_s(left_idx);
    right_delay = delay_grid_s(right_idx);

    if right_delay == left_delay
        pdp_out(left_idx) = pdp_out(left_idx) + power_l;
        continue;
    end

    right_weight = (delay_l - left_delay) / (right_delay - left_delay);
    left_weight = 1 - right_weight;

    pdp_out(left_idx) = pdp_out(left_idx) + power_l * left_weight;
    pdp_out(right_idx) = pdp_out(right_idx) + power_l * right_weight;
end
end

function spec_out = local_build_angle_spectrum(ray_cell, angle_grid_deg, use_abs_angle)
spec_out = zeros(numel(angle_grid_deg), 1);

if isempty(ray_cell) || isempty(ray_cell{1})
    return;
end

rays_used = ray_cell{1};
pathAoAs = [rays_used.AngleOfArrival];
angles_deg = pathAoAs(1, :);
if use_abs_angle
    angles_deg = abs(pathAoAs(2, :));
end

power_dB = -[rays_used.PathLoss];
power = 1e-3 * (10.^(0.1 * (power_dB + 30)));

for l = 1:numel(angles_deg)
    spec_out = local_accumulate_linear(spec_out, angle_grid_deg, angles_deg(l), power(l));
end

total_power = sum(spec_out);
if total_power > 0
    spec_out = spec_out / total_power;
end
end

function vec_out = local_accumulate_linear(vec_in, grid, value, weight)
vec_out = vec_in;

if value <= grid(1)
    vec_out(1) = vec_out(1) + weight;
    return;
end

if value >= grid(end)
    vec_out(end) = vec_out(end) + weight;
    return;
end

right_idx = find(grid >= value, 1, "first");
left_idx = right_idx - 1;
left_grid = grid(left_idx);
right_grid = grid(right_idx);

if right_grid == left_grid
    vec_out(left_idx) = vec_out(left_idx) + weight;
    return;
end

right_weight = (value - left_grid) / (right_grid - left_grid);
left_weight = 1 - right_weight;

vec_out(left_idx) = vec_out(left_idx) + weight * left_weight;
vec_out(right_idx) = vec_out(right_idx) + weight * right_weight;
end

function cos_val = local_cosine_similarity(vec_a, vec_b)
norm_a = norm(vec_a);
norm_b = norm(vec_b);

if norm_a == 0 || norm_b == 0
    cos_val = 0;
else
    cos_val = dot(vec_a, vec_b) / (norm_a * norm_b);
end
end
