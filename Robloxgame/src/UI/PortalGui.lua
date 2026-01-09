--[[
    Portal UI Structure
    Defines the UI layout for portal management
]]

return {
    {
        ClassName = "Frame",
        Name = "MainFrame",
        Properties = {
            AnchorPoint = Vector2.new(1, 0.5),
            BackgroundColor3 = Color3.fromRGB(40, 40, 40),
            BackgroundTransparency = 0.2,
            BorderSizePixel = 2,
            Position = UDim2.new(1, -10, 0.5, 0),
            Size = UDim2.new(0, 200, 0, 250)
        },
        Children = {
            {
                ClassName = "UICorner",
                Properties = {
                    CornerRadius = UDim.new(0, 8)
                }
            },
            -- Title
            {
                ClassName = "TextLabel",
                Name = "TitleLabel",
                Properties = {
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 0, 0, 10),
                    Size = UDim2.new(1, 0, 0, 30),
                    Font = Enum.Font.GothamBold,
                    Text = "Portal System",
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                    TextSize = 18
                }
            },
            -- Status Label
            {
                ClassName = "TextLabel",
                Name = "StatusLabel",
                Properties = {
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 0, 0, 40),
                    Size = UDim2.new(1, 0, 0, 20),
                    Font = Enum.Font.Gotham,
                    Text = "Ready",
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                    TextSize = 14
                }
            },
            -- Create Portal Button
            {
                ClassName = "TextButton",
                Name = "CreateButton",
                Properties = {
                    BackgroundColor3 = Color3.fromRGB(100, 200, 100),
                    Position = UDim2.new(0.1, 0, 0, 70),
                    Size = UDim2.new(0.8, 0, 0, 30),
                    Font = Enum.Font.GothamBold,
                    Text = "Create Portal",
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                    TextSize = 14
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
            -- List Portals Button
            {
                ClassName = "TextButton",
                Name = "ListButton",
                Properties = {
                    BackgroundColor3 = Color3.fromRGB(100, 150, 255),
                    Position = UDim2.new(0.1, 0, 0, 110),
                    Size = UDim2.new(0.8, 0, 0, 30),
                    Font = Enum.Font.GothamBold,
                    Text = "List Portals",
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                    TextSize = 14
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
            -- Remove Portal Button
            {
                ClassName = "TextButton",
                Name = "RemoveButton",
                Properties = {
                    BackgroundColor3 = Color3.fromRGB(200, 60, 60),
                    Position = UDim2.new(0.1, 0, 0, 150),
                    Size = UDim2.new(0.8, 0, 0, 30),
                    Font = Enum.Font.GothamBold,
                    Text = "Remove Portal",
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                    TextSize = 14
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
            -- Portal List Frame (initially hidden)
            {
                ClassName = "Frame",
                Name = "PortalListFrame",
                Properties = {
                    BackgroundColor3 = Color3.fromRGB(50, 50, 50),
                    Position = UDim2.new(0, -210, 0, 0),
                    Size = UDim2.new(0, 200, 1, 0),
                    Visible = false
                },
                Children = {
                    {
                        ClassName = "UICorner",
                        Properties = {
                            CornerRadius = UDim.new(0, 8)
                        }
                    },
                    {
                        ClassName = "TextLabel",
                        Name = "ListTitle",
                        Properties = {
                            BackgroundTransparency = 1,
                            Position = UDim2.new(0, 0, 0, 10),
                            Size = UDim2.new(1, 0, 0, 25),
                            Font = Enum.Font.GothamBold,
                            Text = "Active Portals",
                            TextColor3 = Color3.fromRGB(255, 255, 255),
                            TextSize = 16
                        }
                    },
                    {
                        ClassName = "ScrollingFrame",
                        Name = "Container",
                        Properties = {
                            BackgroundTransparency = 1,
                            Position = UDim2.new(0, 5, 0, 40),
                            Size = UDim2.new(1, -10, 1, -50),
                            CanvasSize = UDim2.new(0, 0, 0, 0),
                            ScrollBarThickness = 6
                        }
                    }
                }
            }
        }
    }
}
