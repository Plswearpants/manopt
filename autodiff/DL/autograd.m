function autogradfunc = autograd(problem,fixedrankflag)
% Apply automatic differentiation to computing Euclidean gradient
%
% function autogradfunc = autograd(problem)
% function autogradfunc = autograd(problem,fixedrankflag)
%
% Returns an AcceleratedFunction which is used to compute Euclidean 
% gradients. See https://ch.mathworks.com/help/deeplearning/ref/deep.
% acceleratedfunction.html for more descriptions about AcceleratedFunction.

% Note: to evaluate the Euclidean gradient of a certain point x(x should be
% of type dlarray), call dfeval(autogradfunc,x) instead of autogradfunc(x).

% See also: egradcompute, 
    
    % check availability 
    assert(isfield(problem,'M') && isfield(problem,'cost'),...,
    'problem structure must contain fields M and cost.');
    assert(exist('dlarray', 'file') == 2, ['Deep learning tool box is '... 
    'needed for automatic differentiation'])
    
    % set fixedrankflag to zero if the manifold struct is not 
    % fixed(multilinear)-rank matrices or tensors with an embedded geometry
    if ~exist('fixedrankflag','var')|| isempty(fixedrankflag)
        fixedrankflag = 0;
    end

    % obtain the euclidean gradient function via AD
    costfunction = problem.cost;
    if fixedrankflag == 1
        % AcceleratedFunction can lead to a slow down in this case
        autogradfunc = @(x,A,B) autogradfuncinternelfixedrankembedded(x,A,B);
    elseif fixedrankflag == 0
        func = @(x) autogradfuncinternel(x);
        % accelerate
        try
            autogradfunc = dlaccelerate(func); % Introduced in Matlab 2021a
            clearCache(autogradfunc);
        catch
            warning('manopt:dlaccelerate', ...
                    ['Function dlaccelerate is not available:\nPlease ' ...
                     'upgrade to Matlab 2021a and latest deep\nlearning ' ...
                     'toolbox version if possible.\nMeanwhile, auto-diff ' ...
                     'may be somewhat slower and problem.ehess may need to be removed.\n' ...
                     'To disable this warning: warning(''off'', ''manopt:dlaccelerate'')']);
            autogradfunc = func;
        end
    end
    
    % define Euclidean gradient function
    function [y, egrad] = autogradfuncinternel(x)
            
        y = costfunction(x);
        % in case that the user forgot to take the real part of the cost
        % when dealing with complex problems, take the real part for AD
        if isstruct(y) && isfield(y,'real')
            y = creal(y);
        end
        
        % call dlgradient to compute the Euclidean gradient. by default, 
        % 'RetainData' and 'EnableHigherDerivatives' are set to false
        egrad = dlgradient(y,x);
        
        % in case that the user is optimizing over anchoredrotationsfactory
        % egrad of anchors with indices in A should be zero
        if (contains(problem.M.name(),'Product rotations manifold') &&..., 
            contains(problem.M.name(),'anchors'))
            A = problem.M.A;
            egrad(:, :, A) = 0;
        end
    end
    
    % obtain the product of egrad and V and the product of egrad
    % transpose and U by differentiating g1 and g2 w.r.t A and B
    function [g1,egrad] = autogradfuncinternelfixedrankembedded(x,A,B)
        X1.U = A; X1.S = eye(size(x.S,1)); X1.V = x.V;
        X2.U = x.U; X2.S = eye(size(x.S,1)); X2.V = B;
        g1 = costfunction(X1); g2 = costfunction(X2);
        egrad.A = dlgradient(g1,A);  egrad.B = dlgradient(g2,B);
    end

end