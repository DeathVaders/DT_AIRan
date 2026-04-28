fprintf("    Building true reference channel H_ref once.\n");

pm = propagationModel("raytracing");
pm.AngularSeparation = "low";
pm.MaxNumReflections = MaxNumReflections;
pm.MaxRelativePathLoss = MaxRelativePathLoss;
pm.MaxNumDiffractions = MaxNumDiffractions;

num_err = numel(err_levels);
num_d = numel(d_list);

NMSE_mean = nan(num_err, num_d);
SGCS_mean = nan(num_err, num_d);
PDP_COS_mean = nan(num_err, num_d);
AZ_COS_mean = nan(num_err, num_d);
EL_COS_mean = nan(num_err, num_d);

[mx, my] = ndgrid(0:Nx-1, 0:Ny-1);

UE_true = rxsite("Latitude", UE_loc(1), "Longitude", UE_loc(2), ...
                 "AntennaHeight", UE_height, "AntennaAngle", Rx_rotation);
rays_true = raytrace(BS, UE_true, pm);
params_ref = local_extract_ray_params(rays_true);
fprintf("    True-point path count for BS%d UE%d = %d\n", BS_idx, UE_idx, numel(params_ref.ToAs));

H_ref = local_build_channel(params_ref, mx, my, Rx_ant_spacing, f_k, Nc, Nx, Ny);
PDP_ref = local_build_pdp(params_ref.ToAs - min_or_zero(params_ref.ToAs), params_ref.power, PDP_delay_grid_s);
AZ_ref = local_build_angle_spectrum(params_ref.theta, params_ref.power, AZ_angle_grid_deg);
EL_ref = local_build_angle_spectrum(abs(params_ref.elev), params_ref.power, EL_angle_grid_deg);

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

for id = 1:num_d
    d = d_list(id);
    offsets = [-1; 1] * d;

    for ie = 1:num_err
        err_level = err_levels(ie);
        metric_sum = zeros(1, 5);
        metric_count = 0;

        fprintf("    d = %.3g m, DT error = %.3g%%\n", d, err_level * 100);

        for ip = 1:numel(offsets)
            UE_loc_err = UE_loc + offsets(ip) * street_unit;
            UE_err = rxsite("Latitude", UE_loc_err(1), "Longitude", UE_loc_err(2), ...
                            "AntennaHeight", UE_height, "AntennaAngle", Rx_rotation);
            rays_err = raytrace(BS, UE_err, pm);
            params_base = local_extract_ray_params(rays_err);

            for mc = 1:Nmc
                params_dt = local_apply_dt_error(params_base, err_level);
                H_err = local_build_channel(params_dt, mx, my, Rx_ant_spacing, f_k, Nc, Nx, Ny);
                PDP_err = local_build_pdp(params_dt.ToAs - min_or_zero(params_dt.ToAs), params_dt.power, PDP_delay_grid_s);
                AZ_err = local_build_angle_spectrum(params_dt.theta, params_dt.power, AZ_angle_grid_deg);
                EL_err = local_build_angle_spectrum(abs(params_dt.elev), params_dt.power, EL_angle_grid_deg);

                metric_sum = metric_sum + local_compute_metrics(H_ref, H_err, vec_ref, den, norm_ref_sq, PDP_ref, PDP_err, AZ_ref, AZ_err, EL_ref, EL_err);
                metric_count = metric_count + 1;
            end
        end

        metric_mean = metric_sum / metric_count;
        NMSE_mean(ie, id) = metric_mean(1);
        SGCS_mean(ie, id) = metric_mean(2);
        PDP_COS_mean(ie, id) = metric_mean(3);
        AZ_COS_mean(ie, id) = metric_mean(4);
        EL_COS_mean(ie, id) = metric_mean(5);
    end
end

function params = local_extract_ray_params(ray_cell)
params = struct("theta", [], "elev", [], "ToAs", [], "phases", [], "power", []);

if isempty(ray_cell) || isempty(ray_cell{1})
    return;
end

rays_used = ray_cell{1};
pathAoAs = [rays_used.AngleOfArrival];
params.theta = pathAoAs(1, :);
params.elev = pathAoAs(2, :);
params.ToAs = [rays_used.PropagationDelay];
params.phases = [rays_used.PhaseShift];
power_dB = -[rays_used.PathLoss];
params.power = 1e-3 * (10.^(0.1 * (power_dB + 30)));
end

function params_dt = local_apply_dt_error(params_base, err_level)
params_dt = params_base;
L = numel(params_base.ToAs);

if L == 0
    return;
end

wrap180 = @(x) mod(x + 180, 360) - 180;
sigma_az = err_level * 10;
sigma_el = err_level * 10;
toa_scale = 10e-9;

params_dt.theta = wrap180(params_base.theta + (2 * rand(1, L) - 1) * sigma_az);
params_dt.elev = min(max(params_base.elev + (2 * rand(1, L) - 1) * sigma_el, -90), 90);
params_dt.ToAs = params_base.ToAs + (2 * rand(1, L) - 1) .* (err_level * toa_scale);
end

function H_out = local_build_channel(params, mx, my, Rx_ant_spacing, f_k, Nc, Nx, Ny)
H_out = zeros(Nx, Ny, Nc);

for l = 1:numel(params.ToAs)
    rx_response_l = exp(1j * 2 * pi * Rx_ant_spacing * ...
        (mx * cosd(params.elev(l)) * cosd(params.theta(l)) + ...
         my * cosd(params.elev(l)) * sind(params.theta(l))));
    freq_response_l = exp(-1j * 2 * pi * f_k * params.ToAs(l));
    alpha_l = sqrt(params.power(l) / Nc) * exp(1j * params.phases(l));
    H_out = H_out + alpha_l .* rx_response_l .* reshape(freq_response_l, 1, 1, Nc);
end
end

function pdp_out = local_build_pdp(delays_s, powers_w, delay_grid_s)
pdp_out = zeros(numel(delay_grid_s), 1);

if isempty(delays_s)
    return;
end

for l = 1:numel(delays_s)
    pdp_out = local_accumulate_linear(pdp_out, delay_grid_s, delays_s(l), powers_w(l));
end
end

function spec_out = local_build_angle_spectrum(angles_deg, powers_w, angle_grid_deg)
spec_out = zeros(numel(angle_grid_deg), 1);

if isempty(angles_deg)
    return;
end

for l = 1:numel(angles_deg)
    spec_out = local_accumulate_linear(spec_out, angle_grid_deg, angles_deg(l), powers_w(l));
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

function metrics = local_compute_metrics(H_ref, H_err, vec_ref, den, norm_ref_sq, PDP_ref, PDP_err, AZ_ref, AZ_err, EL_ref, EL_err)
diff_t = H_err - H_ref;
num = sum(abs(diff_t(:)).^2);
vec_err = H_err(:);
norm_err_sq = sum(abs(vec_err).^2);
dot_ref_err = sum(conj(vec_ref) .* vec_err);

if den == 0
    nmse = 0;
else
    nmse = num / den;
end

if norm_ref_sq == 0 || norm_err_sq == 0
    sgcs = 0;
else
    sgcs = abs(dot_ref_err)^2 / (norm_ref_sq * norm_err_sq);
end

metrics = [ ...
    nmse, ...
    sgcs, ...
    local_cosine_similarity(PDP_ref, PDP_err), ...
    local_cosine_similarity(AZ_ref, AZ_err), ...
    local_cosine_similarity(EL_ref, EL_err) ...
];
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

function value = min_or_zero(values)
if isempty(values)
    value = 0;
else
    value = min(values);
end
end
