function [is_valid, diagnostics] = validate_logP_plausibility(logP_data)
% Validate logP timing intervals for plausibility
% Returns is_valid (true/false) and diagnostics struct

is_valid = true;
diagnostics = struct();
diagnostics.blank_minus_trial_mean = NaN;
diagnostics.blank_minus_trial_std = NaN;
diagnostics.blank_minus_trial_valid = false;
diagnostics.fix_minus_blank_mean = NaN;
diagnostics.fix_minus_blank_std = NaN;
diagnostics.fix_minus_blank_valid = false;
diagnostics.av_minus_fix_mean = NaN;
diagnostics.av_minus_fix_std = NaN;
diagnostics.av_minus_fix_valid = false;
diagnostics.n_trials_checked = 0;

if ~logP_data.success || isempty(logP_data.trial_st)
    is_valid = false;
    diagnostics.reason = 'logP_data not available';
    return;
end

% Check blankST - TrialST (expected 3.00 ± 0.05)
if ~isempty(logP_data.blank_st) && length(logP_data.blank_st) == length(logP_data.trial_st)
    blank_minus_trial = logP_data.blank_st - logP_data.trial_st;
    diagnostics.blank_minus_trial_mean = mean(blank_minus_trial);
    diagnostics.blank_minus_trial_std = std(blank_minus_trial);
    diagnostics.blank_minus_trial_valid = abs(diagnostics.blank_minus_trial_mean - 3.00) < 0.05 && ...
                                         diagnostics.blank_minus_trial_std < 0.1;
    diagnostics.n_trials_checked = length(blank_minus_trial);
    
    if ~diagnostics.blank_minus_trial_valid
        is_valid = false;
        diagnostics.reason = sprintf('blankST-TrialST invalid: mean=%.3f (expected 3.00±0.05)', ...
            diagnostics.blank_minus_trial_mean);
    end
end

% Check fixST - blankST (expected 0.25 ± 0.05)
if ~isempty(logP_data.fix_st) && ~isempty(logP_data.blank_st) && ...
   length(logP_data.fix_st) == length(logP_data.blank_st)
    fix_minus_blank = logP_data.fix_st - logP_data.blank_st;
    diagnostics.fix_minus_blank_mean = mean(fix_minus_blank);
    diagnostics.fix_minus_blank_std = std(fix_minus_blank);
    diagnostics.fix_minus_blank_valid = abs(diagnostics.fix_minus_blank_mean - 0.25) < 0.05 && ...
                                        diagnostics.fix_minus_blank_std < 0.1;
    
    if ~diagnostics.fix_minus_blank_valid
        is_valid = false;
        if ~isfield(diagnostics, 'reason')
            diagnostics.reason = '';
        end
        diagnostics.reason = [diagnostics.reason, sprintf('; fixST-blankST invalid: mean=%.3f (expected 0.25±0.05)', ...
            diagnostics.fix_minus_blank_mean)];
    end
end

% Check A/V_ST - fixST (expected 0.50-0.55, accept 0.40-0.70)
if ~isempty(logP_data.av_st) && ~isempty(logP_data.fix_st) && ...
   length(logP_data.av_st) == length(logP_data.fix_st)
    av_minus_fix = logP_data.av_st - logP_data.fix_st;
    diagnostics.av_minus_fix_mean = mean(av_minus_fix);
    diagnostics.av_minus_fix_std = std(av_minus_fix);
    diagnostics.av_minus_fix_valid = diagnostics.av_minus_fix_mean >= 0.40 && ...
                                     diagnostics.av_minus_fix_mean <= 0.70 && ...
                                     diagnostics.av_minus_fix_std < 0.1;
    
    if ~diagnostics.av_minus_fix_valid
        is_valid = false;
        if ~isfield(diagnostics, 'reason')
            diagnostics.reason = '';
        end
        diagnostics.reason = [diagnostics.reason, sprintf('; A/V_ST-fixST invalid: mean=%.3f (expected 0.40-0.70)', ...
            diagnostics.av_minus_fix_mean)];
    end
end

if is_valid && ~isfield(diagnostics, 'reason')
    diagnostics.reason = 'all checks passed';
end

end
