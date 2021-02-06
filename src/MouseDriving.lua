--- ${title}

---@author ${author}
---@version r_version_r
---@date 04/02/2021

MouseDriving = {}
MouseDriving.MOD_NAME = g_currentModName
MouseDriving.BASE_DEADZONE = 0.1
MouseDriving.BASE_SENSITIVITY = 30

function MouseDriving.initSpecialization()
    MouseDriving.hud = AxisHud:new()
end

function MouseDriving.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Drivable, specializations)
end

function MouseDriving.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "toggleMouseDriving", MouseDriving.toggleMouseDriving)
end

function MouseDriving.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onPreLoad", MouseDriving)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate", MouseDriving)
    SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", MouseDriving)
    SpecializationUtil.registerEventListener(vehicleType, "onDelete", MouseDriving)
    SpecializationUtil.registerEventListener(vehicleType, "onDraw", MouseDriving)
end

function MouseDriving:onPreLoad(savegame)
    ---@type table
    self.spec_mouseDriving = self[string.format("spec_%s.mouseDriving", MouseDriving.MOD_NAME)]
    local spec = self.spec_mouseDriving
    spec.enabled = false

    spec.realSteerAxis = 0
    spec.computedSteerAxis = 0

    spec.realThrottleAxis = 0
    spec.computedThrottleAxis = 0

    spec.mouseSensitivityMultiplier = 1
    spec.mouseDeadZoneMultiplier = 1

    spec.mouseSensitivity = spec.mouseSensitivityMultiplier * MouseDriving.BASE_SENSITIVITY
    spec.mouseDeadZone = spec.mouseDeadZoneMultiplier * MouseDriving.BASE_DEADZONE

    MouseDrivingMain:addSettingsChangeListener(self, MouseDriving.onSettingsChanged)
end

function MouseDriving:onDelete()
    MouseDrivingMain:removeSettingsChangeListener(self)
end

function MouseDriving.onSettingsChanged(self, deadZone, sensitivity)
    local spec = self.spec_mouseDriving
    if deadZone ~= nil then
        spec.mouseDeadZoneMultiplier = deadZone
        spec.mouseDeadZone = spec.mouseDeadZoneMultiplier * MouseDriving.BASE_DEADZONE
    end

    if sensitivity ~= nil then
        spec.mouseSensitivityMultiplier = sensitivity
        spec.mouseSensitivity = spec.mouseSensitivityMultiplier * MouseDriving.BASE_SENSITIVITY
    end
end

function MouseDriving:onUpdate(dt, _, _, _)
    if self:getIsEntered() then
        local spec = self.spec_mouseDriving

        if g_inputBinding.pressedMouseComboMask == 0 and spec.enabled and not g_inputBinding:getShowMouseCursor() then
            if math.abs(g_inputBinding.mouseMovementX) > 0.0005 then
                spec.realSteerAxis = Utility.clamp(-1 - spec.mouseDeadZone, spec.realSteerAxis + (g_inputBinding.mouseMovementX * spec.mouseSensitivity), 1 + spec.mouseDeadZone)
            end
            if math.abs(g_inputBinding.mouseMovementY) > 0.0005 then
                spec.realThrottleAxis = Utility.clamp(-1 - spec.mouseDeadZone, spec.realThrottleAxis + (g_inputBinding.mouseMovementY * spec.mouseSensitivity), 1 + spec.mouseDeadZone)
            end
        end

        if spec.realSteerAxis <= -spec.mouseDeadZone then
            spec.computedSteerAxis = spec.realSteerAxis + spec.mouseDeadZone
        elseif spec.realSteerAxis >= spec.mouseDeadZone then
            spec.computedSteerAxis = spec.realSteerAxis - spec.mouseDeadZone
        else
            spec.computedSteerAxis = 0
        end

        if spec.realThrottleAxis <= -spec.mouseDeadZone then
            spec.computedThrottleAxis = spec.realThrottleAxis + spec.mouseDeadZone
        elseif spec.realThrottleAxis >= spec.mouseDeadZone then
            spec.computedThrottleAxis = spec.realThrottleAxis - spec.mouseDeadZone
        else
            spec.computedThrottleAxis = 0
        end

        if not g_inputBinding:getShowMouseCursor() then
            if spec.computedThrottleAxis > 0 then
                Drivable.actionEventAccelerate(self, nil, spec.computedThrottleAxis, nil, nil)
            end

            if spec.computedThrottleAxis < 0 then
                Drivable.actionEventBrake(self, nil, math.abs(spec.computedThrottleAxis), nil, nil)
            end

            Drivable.actionEventSteer(self, nil, spec.computedSteerAxis, nil, true, nil, InputDevice.CATEGORY.GAMEPAD)
        end

        if MouseDrivingMain.showHud then
            MouseDriving.hud:setAxisData(spec.computedSteerAxis, spec.computedThrottleAxis)
            MouseDriving.hud:update(dt)
        end
    end
end

function MouseDriving:onDraw()
    local spec = self.spec_mouseDriving
    if self:getIsEntered() and spec.enabled and MouseDrivingMain.showHud then
        MouseDriving.hud:render()
    end
end

function MouseDriving:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
    local spec = self.spec_mouseDriving
    if self:getIsEntered() then
        self:clearActionEventsTable(spec.actionEvents)
        if self:getIsActiveForInput(true, true) then
            local _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.MD_TOGGLE, self, MouseDriving.onToggleMouseDriving, false, true, false, true, nil, nil, true)
            g_inputBinding:setActionEventTextVisibility(actionEventId, false)
        end
    end
end

function MouseDriving:toggleMouseDriving(enabled)
    local spec = self.spec_mouseDriving
    spec.enabled = enabled
    spec.realSteerAxis = 0
    spec.computedSteerAxis = 0
    spec.realThrottleAxis = 0
    spec.computedThrottleAxis = 0
end

function MouseDriving.onToggleMouseDriving(self, actionName, inputValue, callbackState, isAnalog, isMouse)
    local spec = self.spec_mouseDriving
    self:toggleMouseDriving(not spec.enabled)
end
