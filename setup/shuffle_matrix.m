function shuffled_matrix = shuffle_matrix(original_matrix, column_indices, max_repeats, max_attempts)
%SHUFFLE_MATRIX Shuffle rows of a matrix with consecutive repeat constraints.
%
%   shuffled_matrix = SHUFFLE_MATRIX(original_matrix, column_indices, max_repeats, max_attempts)
%
%   Shuffles the rows of 'original_matrix' such that in the specified 
%   'column_indices', no value appears more than 'max_repeats' times 
%   consecutively. The function attempts up to 'max_attempts' shuffles 
%   to satisfy the constraint.
%
%   Inputs:
%       original_matrix  - Numeric matrix to shuffle (rows are permuted).
%       column_indices   - Scalar or vector specifying column(s) to check.
%       max_repeats      - Maximum allowed consecutive repeats per column.
%                          Can be scalar or vector matching length of
%                          column_indices.
%                          Use 1 to disallow any consecutive repeats (i.e., no repeats).
%                          Default is 2.
%       max_attempts     - Maximum shuffle attempts before error (default = 1000).
%
%   Output:
%       shuffled_matrix  - The shuffled matrix satisfying the constraints.
%
%   Example:
%       A = [1 10; 2 20; 1 30; 3 40; 3 50];
%       % Allow max 2 repeats in col 1, no repeats in col 2
%       B = shuffle_matrix(A, [1 2], [2 1]);
%
%   See also RANDPERM.
%
%   Written by Justin Frandsen, Date: 2025/08/05 yyyy/mm/dd
    % Default parameters
    if nargin < 3
        max_repeats = 2;
    end
    if nargin < 4
        max_attempts = 1000;
    end

    % If max_repeats is scalar, replicate it to match columns length
    if isscalar(max_repeats)
        max_repeats = repmat(max_repeats, size(column_indices));
    elseif length(max_repeats) ~= length(column_indices)
        error('Length of max_repeats must be 1 or equal to length of column_indices');
    end

    attempt = 0;
    n_rows = size(original_matrix, 1);

    while attempt < max_attempts
        attempt = attempt + 1;
        shuffled_matrix = original_matrix(randperm(n_rows), :);
        valid = true;

        for idx = 1:length(column_indices)
            col_idx = column_indices(idx);
            col = shuffled_matrix(:, col_idx);
            repeat_count = 1;

            for i = 2:n_rows
                if col(i) == col(i-1)
                    repeat_count = repeat_count + 1;
                    if repeat_count > max_repeats(idx)
                        valid = false;
                        break;
                    end
                else
                    repeat_count = 1;
                end
            end

            if ~valid
                break;
            end
        end

        if valid
            return;  % Success
        end
    end

    error('Failed to find a valid shuffle after %d attempts.', max_attempts);
end