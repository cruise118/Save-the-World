--[[
    Size Control UI Structure
    This defines the UI layout that will be created in StarterGui
]]

-- This file will be used by Rojo to create the UI structure
-- The actual UI elements will be defined in the project.json

return {
    -- Size Control Frame
    {
        ClassName = "Frame",
        Name = "MainFrame",
        Properties = {
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = Color3.fromRGB(40, 40, 40),
            BackgroundTransparency = 0.2,
            BorderSizePixel = 2,
            Position = UDim2.new(0, 10, 0.5, 0),
            Size = UDim2.new(0, 150, 0, 120)
        },
        Children = {
            -- UICorner for rounded edges
            {
                ClassName = "UICorner",
                Properties = {
                    CornerRadius = UDim.new(0, 8)
                }
            },
            -- Size Label
            {
                ClassName = "TextLabel",
                Name = "SizeLabel",
                Properties = {
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 0, 0, 10),
                    Size = UDim2.new(1, 0, 0, 30),
                    Font = Enum.Font.GothamBold,
                    Text = "Size: 1.0x",
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                    TextSize = 18
                }
            },
            -- Increase Button
            {
                ClassName = "TextButton",
                Name = "IncreaseButton",
                Properties = {
                    BackgroundColor3 = Color3.fromRGB(60, 200, 60),
                    Position = UDim2.new(0.1, 0, 0, 50),
                    Size = UDim2.new(0.8, 0, 0, 25),
                    Font = Enum.Font.GothamBold,
                    Text = "+ Increase",
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                    TextSize = 16
                },
                Children = {
                    {
                        ClassName = "UICorner",
                        Properties = {
                            CornerRadius = UDim.new(0, 6)
                        }
                    }
                }
            },
            -- Decrease Button
            {
                ClassName = "TextButton",
                Name = "DecreaseButton",
                Properties = {
                    BackgroundColor3 = Color3.fromRGB(200, 60, 60),
                    Position = UDim2.new(0.1, 0, 0, 85),
                    Size = UDim2.new(0.8, 0, 0, 25),
                    Font = Enum.Font.GothamBold,
                    Text = "- Decrease",
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                    TextSize = 16
                },
                Children = {
                    {
                        ClassName = "UICorner",
                        Properties = {
                            CornerRadius = UDim.new(0, 6)
                        }
                    }
                }
            }
        }
    }
}
