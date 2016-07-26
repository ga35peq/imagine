function viewDrag(obj, hObject, eventdata)

dSENSITIVITY            = 0.02;     % Defines mouse sensitivity for windowing operation
dROTATION_THRESHOLD     = 50;       % Defines the number of pixels the cursor has to move to rotate an image

% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
% Get some frequently used values
iD = get(obj.hF, 'CurrentPoint') - obj.SAction.iPos;

iSeries = obj.SAction.SView.iData(1);
iDim    = obj.SData(iSeries).iDims(obj.SAction.SView.iDimInd, :);

if norm(iD) > 2, obj.SAction.lMoved = true; end

switch obj.getTool
    
    % ---------------------------------------------------------------------
    % The NORMAL CURSOR: select, move, zoom, window
    case {'cursor', 'cursor_mask'}
        switch get(hObject, 'SelectionType')
            
            % -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
            % Normal, left mouse button -> MOVE operation
            case 'normal'
                if obj.isOn('2d'), obj.dGrid = -1; end
                
                dD = flip(double(iD));
                if strcmp(get(obj.SAction.SView.hAxes, 'YDir'), 'reverse'), dD(1) = -dD(1); end
                if strcmp(get(obj.SAction.SView.hAxes, 'XDir'), 'reverse'), dD(2) = -dD(2); end
                
                % -   -   -   -   -   -   -   -   -   -   -   -   -   -   -
                % Apply
                if strcmp(obj.getTool, 'cursor')
                    % Move the whole thing
                    for iI = 1:length(obj.SData)
                        obj.SData(iI).dDrawCenter(iDim(1:2)) = obj.SAction.dDrawCenter(iDim(1:2), iI)' - ...
                            dD./obj.SData(iI).dZoom.*min(obj.SData(iI).dRes([1 2 4]));
                    end
                else
                    % Relatively move the mask
                    iInd = obj.cMapping{1}(2);
                    for iI = iInd(iInd > 0)
                        obj.SData(iI).dOrigin(iDim(1:2)) = obj.SAction.dOrigin(iDim(1:2), iI)' + ...
                            dD./obj.SData(iI).dZoom.*min(obj.SData(iI).dRes([1 2 4]));
                    end
                end
                obj.position;
                if obj.isOn('2d') || strcmp(obj.getTool, 'cursor_mask')% Show Crosshair and update other slices
                    obj.draw;
                    obj.showPosition('slice');
                end
                obj.grid;
                
            % -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
            % Shift key or right mouse button -> ZOOM operation
            case 'alt'
                
                for iI = 1:length(obj.SData)
                    if obj.isOn('2d'), obj.dGrid = -1; end

                    dZoom = obj.SAction.dZoomFactor(iI)*exp(dSENSITIVITY.*iD(2));
                    dZoomLog = log2(dZoom);
                    iExp = round(dZoomLog);
                    if abs(dZoomLog - iExp) < 0.05
                        dZoom = 2.^iExp;
                    end 
                    dZoom = max(0.1, min(32, dZoom));
                    
                    if ~obj.isOn('2d')
                        dOldDrawCenter_mm = obj.SAction.dDrawCenter(iDim, 1)';
                        dMouseStart_mm = [obj.SAction.dViewStartPos(2:-1:1), dOldDrawCenter_mm(3)];
                        dD = dOldDrawCenter_mm - dMouseStart_mm;
                        obj.SData(iI).dDrawCenter(iDim) = dMouseStart_mm + obj.SAction.dZoomFactor(iI)./dZoom.*dD;
                    end
                    obj.SData(iI).dZoom = dZoom; % Save ZoomFactor data 
                end
                
                if obj.isOn('2d')
                    iDataInd = obj.SAction.SView.iInd + obj.iStartSeries - 1;
                else
                    iDataInd = obj.iStartSeries;
                end
                obj.tooltip(sprintf('%d %%', round(obj.SData(iDataInd).dZoom*100)));
                
                obj.position;
                obj.grid;
            
            % -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
            % Control key or middle mouse button -> WINDOW operation
            case 'extend'
                if strcmp(obj.getTool, 'cursor')
                    for iI = 1:length(obj.SData)
                        obj.SData(iI).dWindowWidth  = obj.SAction.dWindowWidth(iI) .*exp(dSENSITIVITY*(-iD(2)));
                        obj.SData(iI).dWindowCenter = obj.SAction.dWindowCenter(iI).*exp(dSENSITIVITY*  iD(1));
                    end
                    obj.tooltip(sprintf('Center %g / Width %g', obj.SData(iSeries).dWindowCenter, obj.SData(iSeries).dWindowWidth));
                else
                    for iI = 1:length(obj.cMapping)
                        if length(obj.cMapping{iI}) > 1
                            iInd = obj.cMapping{iI}(2);
                            obj.SData(iInd).dWindowWidth  = obj.SAction.dWindowWidth(iInd) .*exp(dSENSITIVITY*(-iD(2)));
                            obj.SData(iInd).dWindowCenter = obj.SAction.dWindowCenter(iInd).*exp(dSENSITIVITY*  iD(1));
                        end
                    end
                end
                obj.draw;
%                 obj.drawHistogram(1);
        end        
    % ---------------------------------------------------------------------    
        
    
    
    % ---------------------------------------------------------------------
    % The ROTATION tool
    case 'rotate'
        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        % Only proceed if action required (rotation threshold reached)
        lDim = abs(iD) > dROTATION_THRESHOLD;
        if any(lDim)
            
            lFigureDir = iD(lDim) > 0;
            iRotationAxis = iDim(lDim);
            iExchange = setdiff([1 2 4], iRotationAxis);
            if lFigureDir
                iFlipDim = setdiff([1 2 4], iDim);
            else
                iFlipDim = intersect(iExchange, iDim);
            end
            
            for iI = 1:length(obj.SData)
                iDims = obj.SData(iI).iDims;
                iDims(obj.SData(iI).iDims == iExchange(1)) = iExchange(2);
                iDims(obj.SData(iI).iDims == iExchange(2)) = iExchange(1);
                obj.SData(iI).iDims = iDims;
                
                lInvert = obj.SData(iI).lInvert;
                lInvert(iFlipDim) = ~lInvert(iFlipDim);
                obj.SData(iI).lInvert = lInvert;
            end
            set(hObject, 'WindowButtonMotionFcn', @obj.mouseMove);
            obj.draw;
            obj.position;
            obj.grid;
        end
    % END of the rotate tool
    % ---------------------------------------------------------------------
    
    
    % ---------------------------------------------------------------------
    % The FLIP tool
    case 'flip'
        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        % Only proceed if action required (rotation threshold reached)
        lDim = abs(iD) > dROTATION_THRESHOLD;
        if any(lDim)
            
            iDim = iDim(~lDim); % Invert because iD is in x-y format
            for iI = 1:length(obj.SData)
                obj.SData(iI).lInvert(iDim) = ~obj.SData(iI).lInvert(iDim);
            end
            
            set(hObject, 'WindowButtonMotionFcn', @obj.mouseMove);
            obj.draw;
            obj.position;
            obj.grid;
        end
    % END of the flip tool
    % ---------------------------------------------------------------------
    
    case 'swap'
        
        set(obj.SImgs.hUtil, 'Visible', 'on');
                
        dSize = [diff(get(obj.SAxes.hUtil, 'XLim')), diff(get(obj.SAxes.hUtil, 'YLim'))]/2;
        dPos = get(hObject, 'CurrentPoint');
        set(obj.SAxes.hUtil, 'Position', [dPos - dSize/2, dSize]);
        
        iSeries = obj.SView(obj.getView.iInd).iData(1);
        iStartSeries = obj.SView(obj.SAction.iView).iData(1);
        
        if iSeries && iSeries ~= iStartSeries
            switch get(obj.hF, 'SelectionType')
                
                case 'normal'
                    obj.tooltip(sprintf('Exchange Series %d and %d', iStartSeries, iSeries));
                    
                case 'alt'
                    obj.tooltip(sprintf('Use Series %d as Mask for %d', iStartSeries, iSeries));
                    
            end
        else
            obj.tooltip('');
        end
        
    case 'profile'
        
        dPos = get(obj.SView(obj.SAction.iView).hAxes, 'CurrentPoint');
        dXData = [obj.SAction.dViewStartPos(1, 1), dPos(1, 1)];
        dYData = [obj.SAction.dViewStartPos(1, 2), dPos(1, 2)];
        
        if strcmp(get(obj.hF, 'SelectionType'), 'extend')
            if abs(diff(dXData)) < abs(diff(dYData))
                dXData(2) = dXData(1);
            else
                dYData(2) = dYData(1);
            end
        end
        
        iDim = obj.SData(obj.SView(obj.SAction.iView).iData(1)).iDims(obj.SView(obj.SAction.iView).iDimInd, :);
        for iView = 1:numel(obj.SView)
            SView = obj.SView(iView);
            if all(iDim == obj.SData(SView.iData(1)).iDims(SView.iDimInd, :));
                set(SView.hLine, 'XData', dXData, 'YData', dYData, 'Visible', 'on');
            else
                set(SView.hLine, 'Visible', 'off');
            end
        end
        
        obj.sROIMode = 'line';
        
    case 'roi'
        
        iSeries = obj.SView(obj.SAction.iView).iData;
        iDim = obj.SData(obj.SView(obj.SAction.iView).iData).iDims(obj.SView(obj.SAction.iView).iDimInd, :);
        dPos = get(obj.SView(obj.SAction.iView).hAxes, 'CurrentPoint');
        
        iSize = size(obj.SData(iSeries).dImg);
        iSize = iSize(iDim);
        dRes = obj.SData(iSeries).dRes(iDim);
        dOrigin = obj.SData(iSeries).dOrigin(iDim);
        d3rdLim = dOrigin(3) + [0 iSize(3).*dRes(3)];
        
        dLim(:,iDim(1)) = [obj.SAction.dViewStartPos(1, 2); mean([obj.SAction.dViewStartPos(1, 2), dPos(1, 2)]); dPos(1, 2)];
        dLim(:,iDim(2)) = [obj.SAction.dViewStartPos(1, 1); mean([obj.SAction.dViewStartPos(1, 1), dPos(1, 1)]); dPos(1, 1)];
        dLim(:,iDim(3)) = [d3rdLim(1); mean(d3rdLim); d3rdLim(2)];
        
        for iView = 1:numel(obj.SView)
            SView = obj.SView(iView);
            iDim = obj.SData(SView.iData).iDims(SView.iDimInd, :);
            dXData = [dLim(1, iDim(2)) dLim(2, iDim(2)) dLim(3, iDim(2)) dLim(3, iDim(2)) dLim(3, iDim(2)) dLim(2, iDim(2)) dLim(1, iDim(2)) dLim(1, iDim(2)) dLim(1, iDim(2))];
            dYData = [dLim(1, iDim(1)) dLim(1, iDim(1)) dLim(1, iDim(1)) dLim(2, iDim(1)) dLim(3, iDim(1)) dLim(3, iDim(1)) dLim(3, iDim(1)) dLim(2, iDim(1)) dLim(1, iDim(1))];
            set(obj.SView(iView).hLine, 'XData', dXData, 'YData', dYData, 'Visible', 'on');
        end
        
    otherwise
        
end
% end of the TOOL switch statement
% -----------------------------------------------------------------

% drawnow update