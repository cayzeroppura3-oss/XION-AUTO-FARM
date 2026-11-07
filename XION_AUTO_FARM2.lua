-- ================================================================
--  XION AUTO FARM  |  Single LocalScript
--  Place inside: StarterPlayerScripts
--  Automatically finds and collects ALL ProximityPrompts in workspace
-- ================================================================

local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService  = game:GetService("TweenService")

local player  = Players.LocalPlayer
local gui     = player:WaitForChild("PlayerGui")

-- ── Settings ─────────────────────────────────────────────────────
local COLLECT_DELAY   = 0.15   -- seconds between each collect
local WALK_TIMEOUT    = 12     -- max seconds to walk to a plant before skipping
local REACH_DISTANCE  = 5      -- studs — how close before triggering prompt

-- ── State ────────────────────────────────────────────────────────
local farming    = false
local collected  = 0
local farmThread = nil

-- ════════════════════════════════════════════════════════════════
--  UI
-- ════════════════════════════════════════════════════════════════
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name            = "XionAutoFarm"
ScreenGui.ResetOnSpawn    = false
ScreenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset  = true
ScreenGui.Parent          = gui

-- Detect mobile
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- Main window — top right to avoid joystick (bottom left) and jump button (bottom right)
local Frame = Instance.new("Frame")
Frame.Name              = "Main"
Frame.Size              = isMobile and UDim2.new(0, 260, 0, 170) or UDim2.new(0, 230, 0, 150)
Frame.Position          = isMobile and UDim2.new(1, -276, 0, 20) or UDim2.new(0, 24, 0.5, -75)
Frame.BackgroundColor3  = Color3.fromRGB(10, 10, 16)
Frame.BorderSizePixel   = 0
Frame.Parent            = ScreenGui
Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 12)

local OuterStroke = Instance.new("UIStroke", Frame)
OuterStroke.Color     = Color3.fromRGB(100, 20, 220)
OuterStroke.Thickness = 1.8
OuterStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- Title bar
local TitleBar = Instance.new("Frame")
TitleBar.Size            = isMobile and UDim2.new(1, 0, 0, 48) or UDim2.new(1, 0, 0, 40)
TitleBar.BackgroundColor3 = Color3.fromRGB(100, 20, 220)
TitleBar.BorderSizePixel = 0
TitleBar.ZIndex          = 2
TitleBar.Parent          = Frame
local TitleCorner = Instance.new("UICorner", TitleBar)
TitleCorner.CornerRadius = UDim.new(0, 12)
-- fill bottom of title bar
local TitleFill = Instance.new("Frame", TitleBar)
TitleFill.Size             = UDim2.new(1, 0, 0.5, 0)
TitleFill.Position         = UDim2.new(0, 0, 0.5, 0)
TitleFill.BackgroundColor3 = Color3.fromRGB(100, 20, 220)
TitleFill.BorderSizePixel  = 0
TitleFill.ZIndex           = 2

local TitleLabel = Instance.new("TextLabel", TitleBar)
TitleLabel.Size              = UDim2.new(1, -10, 1, 0)
TitleLabel.Position          = UDim2.new(0, 10, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text              = "⚡  XION AUTO FARM"
TitleLabel.TextColor3        = Color3.fromRGB(255, 255, 255)
TitleLabel.TextSize          = isMobile and 17 or 15
TitleLabel.Font              = Enum.Font.GothamBold
TitleLabel.TextXAlignment    = Enum.TextXAlignment.Left
TitleLabel.ZIndex            = 3

-- Status label
local StatusLabel = Instance.new("TextLabel", Frame)
StatusLabel.Size              = UDim2.new(1, -20, 0, 24)
StatusLabel.Position          = isMobile and UDim2.new(0, 10, 0, 56) or UDim2.new(0, 10, 0, 48)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text              = "Status: Idle"
StatusLabel.TextColor3        = Color3.fromRGB(160, 160, 180)
StatusLabel.TextSize          = isMobile and 15 or 13
StatusLabel.Font              = Enum.Font.Gotham
StatusLabel.TextXAlignment    = Enum.TextXAlignment.Left
StatusLabel.ZIndex            = 2

-- Collected counter
local CountLabel = Instance.new("TextLabel", Frame)
CountLabel.Size              = UDim2.new(1, -20, 0, 20)
CountLabel.Position          = isMobile and UDim2.new(0, 10, 0, 80) or UDim2.new(0, 10, 0, 70)
CountLabel.BackgroundTransparency = 1
CountLabel.Text              = "Collected: 0"
CountLabel.TextColor3        = Color3.fromRGB(120, 120, 140)
CountLabel.TextSize          = isMobile and 14 or 12
CountLabel.Font              = Enum.Font.Gotham
CountLabel.TextXAlignment    = Enum.TextXAlignment.Left
CountLabel.ZIndex            = 2

-- Toggle button
local ToggleBtn = Instance.new("TextButton", Frame)
ToggleBtn.Size               = isMobile and UDim2.new(1, -24, 0, 48) or UDim2.new(1, -24, 0, 38)
ToggleBtn.Position           = isMobile and UDim2.new(0, 12, 0, 110) or UDim2.new(0, 12, 0, 100)
ToggleBtn.BackgroundColor3   = Color3.fromRGB(30, 30, 42)
ToggleBtn.Text               = "START FARMING"
ToggleBtn.TextColor3         = Color3.fromRGB(220, 220, 255)
ToggleBtn.TextSize           = isMobile and 16 or 14
ToggleBtn.Font               = Enum.Font.GothamBold
ToggleBtn.BorderSizePixel    = 0
ToggleBtn.ZIndex             = 2
local BtnCorner = Instance.new("UICorner", ToggleBtn)
BtnCorner.CornerRadius = UDim.new(0, 8)
local BtnStroke = Instance.new("UIStroke", ToggleBtn)
BtnStroke.Color     = Color3.fromRGB(100, 20, 220)
BtnStroke.Thickness = 1.4

-- ── Draggable title bar ──────────────────────────────────────────
local dragging, dragStart, frameStart
TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging   = true
        dragStart  = input.Position
        frameStart = Frame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - dragStart
        Frame.Position = UDim2.new(
            frameStart.X.Scale, frameStart.X.Offset + d.X,
            frameStart.Y.Scale, frameStart.Y.Offset + d.Y
        )
    end
end)

-- ════════════════════════════════════════════════════════════════
--  FARM LOGIC
-- ════════════════════════════════════════════════════════════════

-- Only collect prompts that say "Grab" OR whose parent is a tomato/carrot
local function isHarvestPrompt(prompt)
    local action = prompt.ActionText:lower()
    local object = prompt.ObjectText:lower()
    local pName  = prompt.Parent and prompt.Parent.Name:lower() or ""
    return object:find("grab") or action:find("grab")
        or pName:find("tomato") or pName:find("carrot")
end

-- Get all valid harvest prompts
local function getPrompts()
    local list = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled and isHarvestPrompt(obj) then
            table.insert(list, obj)
        end
    end
    return list
end

-- Get the position of a prompt's parent part
local function getPartPos(prompt)
    local part = prompt.Parent
    if not part then return nil end
    if part:IsA("BasePart") then return part.Position end
    if part:IsA("Model") then
        if part.PrimaryPart then return part.PrimaryPart.Position end
        local cf, _ = part:GetBoundingBox()
        return cf.Position
    end
    return nil
end

-- Walk character to pos and wait until within activation range
local function walkTo(pos, activationDist)
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local root     = char:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root then return end

    local stopAt = math.max((activationDist or REACH_DISTANCE) - 1, 2)
    humanoid:MoveTo(pos)

    local elapsed = 0
    while elapsed < WALK_TIMEOUT do
        if not farming then return end
        if (root.Position - pos).Magnitude <= stopAt then break end
        task.wait(0.1)
        elapsed = elapsed + 0.1
    end
end

-- Trigger a G-hold prompt (hold duration 3 seconds)
local function triggerPrompt(prompt)
    if not prompt or not prompt.Parent then return end
    local holdTime = prompt.HoldDuration > 0 and prompt.HoldDuration or 3
    pcall(function()
        prompt:InputHoldBegin()
        local elapsed = 0
        while elapsed < holdTime do
            if not farming or not prompt or not prompt.Parent then
                pcall(function() prompt:InputHoldEnd() end)
                return
            end
            task.wait(0.1)
            elapsed = elapsed + 0.1
        end
        prompt:InputHoldEnd()
    end)
end

-- Main farm loop
local function startFarm()
    farming   = true
    collected = 0
    StatusLabel.Text       = "Status: Farming..."
    StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 140)
    ToggleBtn.Text         = "STOP FARMING"
    TweenService:Create(ToggleBtn, TweenInfo.new(0.2), {
        BackgroundColor3 = Color3.fromRGB(100, 20, 220)
    }):Play()

    farmThread = task.spawn(function()
        while farming do
            local prompts = getPrompts()
            if #prompts == 0 then
                StatusLabel.Text = "Status: Waiting for crops..."
                task.wait(1)
            else
                StatusLabel.Text = "Status: Farming... (" .. #prompts .. " crops)"
                for _, prompt in ipairs(prompts) do
                    if not farming then break end
                    if prompt and prompt.Parent then
                        local pos = getPartPos(prompt)
                        if pos then
                            walkTo(pos, prompt.MaxActivationDistance)
                            task.wait(0.1)
                            if prompt and prompt.Parent and prompt.Enabled then
                                triggerPrompt(prompt)
                                collected = collected + 1
                                CountLabel.Text = "Collected: " .. collected
                                task.wait(COLLECT_DELAY)
                            end
                        end
                    end
                end
            end
            task.wait(0.2)
        end
    end)
end

local function stopFarm()
    farming = false
    if farmThread then
        task.cancel(farmThread)
        farmThread = nil
    end
    StatusLabel.Text       = "Status: Idle"
    StatusLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
    ToggleBtn.Text         = "START FARMING"
    TweenService:Create(ToggleBtn, TweenInfo.new(0.2), {
        BackgroundColor3 = Color3.fromRGB(30, 30, 42)
    }):Play()
end

-- Toggle button
ToggleBtn.MouseButton1Click:Connect(function()
    if farming then
        stopFarm()
    else
        startFarm()
    end
end)

-- Stop farming if character dies
player.CharacterAdded:Connect(function()
    if farming then
        stopFarm()
        task.wait(2)
        startFarm()   -- restart after respawn
    end
end)
