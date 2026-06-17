return function(options)
    options = options or {}

    local fontSize = options.fontSize or 7
    local black = options.black or Color3.new(0, 0, 0)
    local watermarkPrefixes = options.watermarkPrefixes or {"Clash:", "XSaw:", "Burst:", "Choke:"}

    local myMouse = options.mouse
    if not myMouse then
        local sourcePlayer = options.player or game:GetService("Players").LocalPlayer
        myMouse = sourcePlayer:GetMouse()
    end

    local UILib = {}
    UILib.__index = UILib



    local function clamp(x, a, b)
        if x > b then
            return b
        elseif x < a then
            return a
        else
            return x
        end
    end

    local function color3fromHSV(h, s, v)
        local i = math.floor(h * 6)
        local f = h * 6 - i
        local p = v * (1 - s)
        local q = v * (1 - f * s)
        local t = v * (1 - (1 - f) * s)
        i = i % 6
        local r, g, b
        if i == 0 then
            r, g, b = v, t, p
        elseif i == 1 then
            r, g, b = q, v, p
        elseif i == 2 then
            r, g, b = p, v, t
        elseif i == 3 then
            r, g, b = p, q, v
        elseif i == 4 then
            r, g, b = t, p, v
        else
            r, g, b = v, p, q
        end

        return {r * 255, g * 255, b * 255}
    end

    local function getMousePos()
        return Vector2.new(myMouse.X, myMouse.Y)
    end

    local function lerp(a, b, t)
        return a + (b - a) * t
    end

    local function getDynamicWatermarkKey(segment)
        for _, prefix in ipairs(watermarkPrefixes) do
            if segment:sub(1, #prefix) == prefix then
                return prefix:sub(1, #prefix - 1)
            end
        end

        return nil
    end

    local function hideDrawings(drawingsTable)
        for _, drawing in pairs(drawingsTable) do
            drawing.Visible = false
        end
    end

    local function removeDrawings(drawingsTable)
        for _, drawing in ipairs(drawingsTable) do
            drawing:Remove()
        end
    end

    local function square(color, filled, thickness)
        local drawing = Drawing.new('Square')
        if filled ~= nil then
            drawing.Filled = filled
        end
        if thickness then
            drawing.Thickness = thickness
        end
        if color then
            drawing.Color = color
        end
        return drawing
    end

    local function textLine(value, color)
        local drawing = Drawing.new('Text')
        drawing.Text = value or ''
        drawing.Outline = true
        if color then
            drawing.Color = color
        end
        return drawing
    end

    function UILib._GetTextBounds(str)
        return #str * fontSize, fontSize
    end

    function UILib._IsMouseWithinBounds(origin, size)
        local mousePos = getMousePos()
        return mousePos.x >= origin.x and mousePos.x <= origin.x + size.x and
        mousePos.y >= origin.y and mousePos.y <= origin.y + size.y
    end

    function UILib:_RemoveDropdown()
        if self._active_dropdown then
            removeDrawings(self._active_dropdown._drawings)
            self._active_dropdown = nil
        end
    end

    function UILib:_RemoveColorpicker()
        if self._active_colorpicker then
            removeDrawings(self._active_colorpicker._drawings)
            self._active_colorpicker = nil
        end
    end

    function UILib:_SpawnDropdown(default, choices, multi, callback, position, width)
        if self._active_dropdown then
            self:_RemoveDropdown()
        end

        local base = square(self._color_surface, true)
        local crust = square(self._color_crust, false, 1)
        local border = square(self._color_border, false, 1)

        local drawings = { base, crust, border }
        for _, entryValue in ipairs(choices) do
            local entry = textLine(entryValue, self._color_text)
            table.insert(drawings, entry)
        end

        local choiceHash = {}
        for _, choice in ipairs(choices) do
            choiceHash[choice] = false
        end

        for _, default_ in ipairs(default) do
            choiceHash[default_] = true
        end

        self._active_dropdown = {
            choices = choiceHash, multi = multi, callback = callback,
            position = position, w = width, _drawings = drawings
        }
    end

    function UILib:_SpawnColorpicker(default, colorLabel, callback)
        if self._active_colorpicker then
            self:_RemoveColorpicker()
        end

        local base = square(self._color_surface, true)
        local crust = square(self._color_crust, false, 1)
        local border = square(self._color_border, false, 1)
        local titleBar = square(self._color_border, true)
        local label = textLine(colorLabel, self._color_text)
        local preview = square(self._color_surface, true)

        local drawings = { base, crust, border, titleBar, label, preview }

        for _ = 1, self._gradient_detail * 3 do
            local segment = Drawing.new('Square')
            segment.Filled = true
            table.insert(drawings, segment)
        end

        local cursorCrustPrimary = Drawing.new('Circle')
        cursorCrustPrimary.Filled = false
        cursorCrustPrimary.Thickness = 3
        cursorCrustPrimary.Radius = 6
        cursorCrustPrimary.NumSides = 20
        cursorCrustPrimary.Color = self._color_crust

        local cursorBasePrimary = Drawing.new('Circle')
        cursorBasePrimary.Filled = false
        cursorBasePrimary.Thickness = 1
        cursorBasePrimary.Radius = 6
        cursorBasePrimary.NumSides = 20
        cursorBasePrimary.Color = self._color_border

        local cursorBaseSecondary = Drawing.new('Square')
        cursorBaseSecondary.Filled = true
        cursorBaseSecondary.Color = self._color_border
        local cursorBorderSecondary = Drawing.new('Square')
        cursorBorderSecondary.Filled = false
        cursorBorderSecondary.Thickness = 1
        cursorBorderSecondary.Color = self._color_surface
        local cursorCrustSecondary = Drawing.new('Square')
        cursorCrustSecondary.Filled = false
        cursorCrustSecondary.Thickness = 1
        cursorCrustSecondary.Color = self._color_crust

        for _, cursor in ipairs{cursorBasePrimary, cursorCrustPrimary, cursorBaseSecondary, cursorCrustSecondary, cursorBorderSecondary} do
            table.insert(drawings, cursor)
        end

        self._active_colorpicker = {
            callback = callback, _pallete_pos = nil, _slider_y = 0, _drawings = drawings
        }
    end

    local function keyEntry(id)
        return { id = id, held = false, click = false }
    end

    local function buildInputs()
        local inputs = {
            m1 = keyEntry(0x01),
            m2 = keyEntry(0x02),
            mb = keyEntry(0x04),
            unbound = keyEntry(0x08),
            tab = keyEntry(0x09),
            enter = keyEntry(0x0D),
            shift = keyEntry(0x10),
            ctrl = keyEntry(0x11),
            alt = keyEntry(0x12),
            pause = keyEntry(0x13),
            capslock = keyEntry(0x14),
            esc = keyEntry(0x1B),
            space = keyEntry(0x20),
            pageup = keyEntry(0x21),
            pagedown = keyEntry(0x22),
            ['end'] = keyEntry(0x23),
            home = keyEntry(0x24),
            left = keyEntry(0x25),
            up = keyEntry(0x26),
            right = keyEntry(0x27),
            down = keyEntry(0x28),
            insert = keyEntry(0x2D),
            delete = keyEntry(0x2E),
            multiply = keyEntry(0x6A),
            add = keyEntry(0x6B),
            separator = keyEntry(0x6C),
            subtract = keyEntry(0x6D),
            decimal = keyEntry(0x6E),
            divide = keyEntry(0x6F),
            numlock = keyEntry(0x90),
            scrolllock = keyEntry(0x91),
            lshift = keyEntry(0xA0),
            rshift = keyEntry(0xA1),
            lctrl = keyEntry(0xA2),
            rctrl = keyEntry(0xA3),
            lalt = keyEntry(0xA4),
            ralt = keyEntry(0xA5),
            semicolon = keyEntry(0xBA),
            plus = keyEntry(0xBB),
            comma = keyEntry(0xBC),
            minus = keyEntry(0xBD),
            period = keyEntry(0xBE),
            slash = keyEntry(0xBF),
            tilde = keyEntry(0xC0),
            lbracket = keyEntry(0xDB),
            backslash = keyEntry(0xDC),
            rbracket = keyEntry(0xDD),
            quote = keyEntry(0xDE),
        }

        for i = 0, 9 do
            inputs[tostring(i)] = keyEntry(0x30 + i)
            inputs["numpad" .. i] = keyEntry(0x60 + i)
        end

        for code = 0x41, 0x5A do
            inputs[string.char(code + 32)] = keyEntry(code)
        end

        for i = 1, 12 do
            inputs["f" .. i] = keyEntry(0x6F + i)
        end

        return inputs
    end

    function UILib.new(name, size, watermarkActivity)
        repeat task.wait(1/9999) until isrbxactive()

        local self = setmetatable({}, UILib)

        self._inputs = buildInputs()

        self._active_tab = nil
        self._open = true
        self._watermark = true
        self._base_opacity = 0
        self._dragging = false
        self._drag_offset = Vector2.new(0, 0)
        self._watermark_dragging = false
        self._watermark_drag_offset = Vector2.new(0, 0)
        self._active_dropdown = nil
        self._active_colorpicker = nil
        self._clipboard_color = nil
        self._tick = os.clock()

        self.identity = name
        self.watermark_x = 20
        self.watermark_y = 20
        self._watermark_activity = watermarkActivity
        self.x = 100
        self.y = 150
        self.w = size and size.x or 600
        self.h = size and size.y or 520

        self._color_accent  = Color3.fromRGB(255, 127, 0)
        self._color_text    = Color3.fromRGB(255, 255, 255)
        self._color_crust   = Color3.fromRGB(0, 0, 0)
        self._color_border  = Color3.fromRGB(30, 30, 30)
        self._color_surface = Color3.fromRGB(20, 20, 20)
        self._color_overlay = Color3.fromRGB(50, 50, 50)

        self._title_h = 25
        self._tab_h = 20
        self._padding = 6
        self._gradient_detail = 80

        local base = square(self._color_surface, true)
        local crust = square(self._color_crust, false, 1)
        local border = square(self._color_border, false, 1)
        local navbar = square(self._color_border, true)
        local title = textLine('', self._color_text)
        title.Visible = false

        local titleText = self.identity
        local titleChars = {}
        for charIndex = 1, #titleText do
            local charDrawing = textLine(titleText:sub(charIndex, charIndex))
            charDrawing.Visible = false
            titleChars[charIndex] = charDrawing
        end
        self._title_chars = titleChars
        self._title_hue = 0

        local watermarkBase = square(self._color_surface, true)
        local watermarkCursor = square(self._color_accent, true)
        local watermarkCrust = square(self._color_crust, false, 1)
        local watermarkBorder = square(self._color_border, false, 1)
        local watermarkText = textLine(name, self._color_text)
        local watermarkQTE = textLine('', self._color_text)
        watermarkQTE.Visible = false

        self._wm_seg_prev      = {}
        self._wm_seg_flash     = {}
        self._wm_qte_flash_dur = 0.55

        local rainbowSegments = 60
        local rbSegs = {}
        for i = 1, rainbowSegments do
            local seg = Drawing.new('Line')
            seg.Thickness = 2
            seg.Visible = false
            rbSegs[i] = seg
        end
        self._rainbow_hue = 0
        self._rb = rbSegs
        self._rb_segs = rainbowSegments

        self._tree = {
            _tabs = {},
            _drawings = { crust, border, base, navbar, title, watermarkBase, watermarkCursor, watermarkCrust, watermarkBorder, watermarkText, watermarkQTE }
        }

        return self
    end

    function UILib:ToggleWatermark(state)
        self._watermark = state
    end

    function UILib:ToggleMenu(state)
        self._open = state
    end

    function UILib:IsMenuOpen()
        return self._open
    end

    function UILib:Tab(name)
        local backdrop = square(self._color_border, true)
        local shadow = square(black, true)
        local cursor = square(self._color_accent, true)
        local text = textLine(name, self._color_text)

        table.insert(self._tree._tabs, {
            name = name,
            _sections = {},
            _drawings = { backdrop, shadow, cursor, text }
        })

        if self._active_tab == nil then
            self._active_tab = name
        end
        return name
    end

    function UILib:Section(tabName, name)
        for _, tab in ipairs(self._tree._tabs) do
            if tab.name == tabName then
                local base = square(self._color_surface, true)
                local crust = square(self._color_crust, false, 1)
                local border = square(self._color_overlay, false, 1)
                local title = textLine(name, self._color_text)

                local section = { name = name, _items = {}, _drawings = { base, crust, border, title } }
                table.insert(tab._sections, section)
                return name
            end
        end
    end

    function UILib:_AddToSection(tabName, sectionName, itemType, value, callback, drawings, meta)
        for _, tab in pairs(self._tree._tabs) do
            if tab.name == tabName then
                for _, section in pairs(tab._sections) do
                    if section.name == sectionName then
                        local item = {
                            type = itemType, value = value,
                            callback = callback, _drawings = drawings
                        }
                        if meta then
                            for key, val in pairs(meta) do item[key] = val end
                        end
                        table.insert(section._items, item)
                        return item
                    end
                end
            end
        end
    end

    function UILib:Checkbox(tabName, sectionName, label, defaultValue, callback)
        local outline = Drawing.new('Square')
        outline.Color = self._color_crust
        outline.Thickness = 1
        outline.Filled = false
        local check = Drawing.new('Square')
        check.Color = self._color_accent
        check.Filled = true
        local checkShadow = Drawing.new('Square')
        checkShadow.Color = black
        checkShadow.Filled = true
        local text = Drawing.new('Text')
        text.Color = self._color_text
        text.Outline = true
        text.Text = label

        return self:_AddToSection(tabName, sectionName, 'checkbox', defaultValue, callback, {
            outline, check, checkShadow, text
        })
    end

    function UILib:Label(tabName, sectionName, text)
        local label = Drawing.new('Text')
        label.Color = self._color_text
        label.Outline = true
        label.Text = text
        self:_AddToSection(tabName, sectionName, 'label', text, nil, { label })
    end

    function UILib:Button(tabName, sectionName, label, callback)
        local outline   = Drawing.new('Square')
        outline.Filled = false
        outline.Thickness = 1
        outline.Color = self._color_crust
        local fill      = Drawing.new('Square')
        fill.Filled = true
        fill.Color = self._color_border
        local shadow    = Drawing.new('Square')
        shadow.Filled = true
        shadow.Color = black
        local text      = Drawing.new('Text')
        text.Outline = true
        text.Color = self._color_text
        text.Text = label

        return self:_AddToSection(tabName, sectionName, 'button', false, callback, {
            outline, fill, shadow, text
        }, { label = label, _held = false })
    end

    function UILib:Slider(tabName, sectionName, label, minValue, maxValue, defaultValue, callback)
        local sliderOutline = Drawing.new('Square')
        sliderOutline.Color = self._color_crust
        sliderOutline.Filled = true
        local sliderFill = Drawing.new('Square')
        sliderFill.Color = self._color_accent
        sliderFill.Filled = true
        local sliderFillShadow = Drawing.new('Square')
        sliderFillShadow.Color = black
        sliderFillShadow.Filled = true
        local sliderValue = Drawing.new('Text')
        sliderValue.Color = self._color_text
        sliderValue.Outline = true
        local sliderText = Drawing.new('Text')
        sliderText.Color = self._color_text
        sliderText.Outline = true
        sliderText.Text = label

        self:_AddToSection(tabName, sectionName, 'slider', defaultValue, callback, {
            sliderOutline, sliderFill, sliderFillShadow, sliderValue, sliderText
        }, { label = label, min = minValue, max = maxValue, step = 1, appendix = '' })
    end

    function UILib:Colorpicker(tabName, sectionName, label, defaultValue, callback)
        local outline = Drawing.new('Square')
        outline.Color = self._color_crust
        outline.Thickness = 1
        outline.Filled = false
        local fill = Drawing.new('Square')
        fill.Color = self._color_crust
        fill.Filled = true
        local shadow = Drawing.new('Square')
        shadow.Color = black
        shadow.Filled = true
        local text = Drawing.new('Text')
        text.Color = self._color_text
        text.Outline = true
        text.Text = label

        return self:_AddToSection(tabName, sectionName, 'colorpicker', defaultValue, callback, {
            outline, fill, shadow, text
        }, { label = label })
    end

    function UILib:Choice(tabName, sectionName, label, defaultValue, callback, choices, multi)
        local outline = Drawing.new('Square')
        outline.Color = self._color_crust
        outline.Thickness = 1
        outline.Filled = false
        local fill = Drawing.new('Square')
        fill.Color = self._color_crust
        fill.Filled = true
        local values = Drawing.new('Text')
        values.Color = self._color_text
        values.Outline = true
        values.Text = label
        local expand = Drawing.new('Text')
        expand.Color = self._color_text
        expand.Outline = true
        expand.Text = label
        local text = Drawing.new('Text')
        text.Color = self._color_text
        text.Outline = true
        text.Text = label

        return self:_AddToSection(tabName, sectionName, 'choice', defaultValue, callback, {
            outline, fill, values, expand, text
        }, { choices = choices, multi = multi })
    end

    function UILib:Keybind(tabName, sectionName, label, defaultValue, callback, mode)
        local text = Drawing.new('Text')
        text.Color = self._color_text
        text.Outline = true
        text.Text = label
        local outline = Drawing.new('Square')
        outline.Color = self._color_crust
        outline.Thickness = 1
        outline.Filled = false
        local fill = Drawing.new('Square')
        fill.Color = self._color_crust
        fill.Filled = true
        local key = Drawing.new('Text')
        key.Color = self._color_text
        key.Outline = true

        return self:_AddToSection(tabName, sectionName, 'key', defaultValue, callback, {
            text, outline, fill, key
        }, { mode = mode or 'Hold', _listening = false, _state = nil })
    end

    function UILib:_UpdateInputs()
        for keycode, inputData in pairs(self._inputs) do
            local keycodeId = inputData.id
            local pressed = keycodeId and isrbxactive() and iskeypressed(keycodeId)

            if pressed then
                inputData.click = inputData.held == false
                inputData.held = true
            else
                inputData.held = false
                inputData.click = false
            end

            self._inputs[keycode] = inputData
        end
    end

    function UILib:_DrawWatermark(deltaTime, mousePos, clickFrame, m1Held)
        local drawings = self._tree._drawings
        local watermarkBase   = drawings[6]
        local watermarkCursor = drawings[7]
        local watermarkCrust  = drawings[8]
        local watermarkBorder = drawings[9]
        local watermarkTitle  = drawings[10]
        local watermarkQTE    = drawings[11]

        if not self._watermark then
            watermarkBase.Visible = false
            watermarkCrust.Visible = false
            watermarkBorder.Visible = false
            watermarkCursor.Visible = false
            watermarkTitle.Visible = false
            watermarkQTE.Visible = false
            return
        end

        local baseStates = {self.identity}
        local dynSegments = {}

        if self._watermark_activity then
            for _, activity in ipairs(self._watermark_activity) do
                if type(activity) == 'function' then
                    local activityString = activity()
                    if activityString and #activityString > 0 then
                        local nonDyn = {}
                        for segment in (activityString .. ' | '):gmatch('([^|]+)%s*|%s*') do
                            segment = segment:match('^%s*(.-)%s*$')
                            local dynKey = getDynamicWatermarkKey(segment)
                            if dynKey then
                                table.insert(dynSegments, { key = dynKey, text = segment })
                            elseif #segment > 0 then
                                table.insert(nonDyn, segment)
                            end
                        end
                        if #nonDyn > 0 then
                            table.insert(baseStates, table.concat(nonDyn, ' | '))
                        end
                    end
                end
            end
        end

        local mainText = table.concat(baseStates, ' | ')

        for _, seg in ipairs(dynSegments) do
            local key = seg.key
            local prev = self._wm_seg_prev[key] or ''
            if seg.text ~= prev then
                self._wm_seg_flash[key] = self._wm_qte_flash_dur
                self._wm_seg_prev[key] = seg.text
            end
            if (self._wm_seg_flash[key] or 0) > 0 then
                self._wm_seg_flash[key] = math.max(0, self._wm_seg_flash[key] - deltaTime)
            end
        end

        local dynStr = ''
        local maxFlash = 0
        if #dynSegments > 0 then
            local parts = {}
            for _, seg in ipairs(dynSegments) do
                table.insert(parts, seg.text)
                local flash = self._wm_seg_flash[seg.key] or 0
                if flash > maxFlash then
                    maxFlash = flash
                end
            end
            dynStr = ' | ' .. table.concat(parts, ' | ')
        end

        local dynColor
        if maxFlash > 0 then
            local t = maxFlash / self._wm_qte_flash_dur
            dynColor = Color3.fromRGB(255, math.floor(lerp(255, 127, t)), math.floor(lerp(255, 0, t)))
        else
            dynColor = self._color_text
        end

        local mainW, mainH = UILib._GetTextBounds(mainText)
        local dynW = dynStr ~= '' and UILib._GetTextBounds(dynStr) or 0
        local watermarkPosition = Vector2.new(self.watermark_x or 20, self.watermark_y or 20)
        local watermarkSize = Vector2.new(mainW + dynW + self._padding * 3, mainH + self._padding * 3)

        watermarkBase.Position = watermarkPosition
        watermarkBase.Size = watermarkSize
        watermarkBase.Visible = true
        watermarkBase.Color = self._color_surface
        watermarkCrust.Position = watermarkPosition
        watermarkCrust.Size = watermarkSize
        watermarkCrust.Visible = true
        watermarkCrust.Color = self._color_crust
        watermarkBorder.Position = watermarkPosition + Vector2.new(1, 1)
        watermarkBorder.Size = watermarkSize + Vector2.new(-2, -2)
        watermarkBorder.Visible = true
        watermarkBorder.Color = self._color_border
        watermarkCursor.Position = watermarkPosition + Vector2.new(2, 2)
        watermarkCursor.Size = Vector2.new(watermarkSize.x - 4, 1)
        watermarkCursor.Visible = true
        watermarkCursor.Color = self._color_accent

        local textOrigin = watermarkPosition + Vector2.new(2 + self._padding, 2 + self._padding)
        watermarkTitle.Position = textOrigin
        watermarkTitle.Text = mainText
        watermarkTitle.Visible = true
        watermarkTitle.Color = self._color_text

        if dynStr ~= '' then
            watermarkQTE.Position = textOrigin + Vector2.new(mainW, 0)
            watermarkQTE.Text = dynStr
            watermarkQTE.Color = dynColor
            watermarkQTE.Visible = true
        else
            watermarkQTE.Visible = false
        end

        if UILib._IsMouseWithinBounds(watermarkPosition, watermarkSize) then
            if clickFrame and not self._dragging then
                self._watermark_dragging = true
                self._watermark_drag_offset = mousePos - watermarkPosition
            end
        end

        if self._watermark_dragging then
            if m1Held then
                self.watermark_x = mousePos.x - self._watermark_drag_offset.x
                self.watermark_y = mousePos.y - self._watermark_drag_offset.y
            else
                self._watermark_dragging = false
            end
        end
    end

    function UILib:Step()
        local deltaTime = math.max(os.clock() - self._tick, 0.0035)
        local mousePos = getMousePos()

        self:_UpdateInputs()

        if self._guiToggleKey and self._inputs[self._guiToggleKey] and self._inputs[self._guiToggleKey].click then
            self._open = not self._open
            self._inputs[self._guiToggleKey].click = false
        end

        local menuOpen = self._open
        local clickFrame = menuOpen and self._inputs.m1.click
        local ctxFrame = menuOpen and self._inputs.m2.click
        local m1Held = menuOpen and self._inputs.m1.held

        local baseOpacity = self._base_opacity
        local childrenVisible = baseOpacity > 0.22
        self._base_opacity = clamp(lerp(baseOpacity, menuOpen and 1 or 0, deltaTime * 11), 0, 1)

        setrobloxinput(not menuOpen)

        self:_DrawWatermark(deltaTime, mousePos, clickFrame, m1Held)

        if self._active_colorpicker then
            local cpDraws = self._active_colorpicker._drawings
            local cpBase = cpDraws[1]
            local cpCrust = cpDraws[2]
            local cpBorder = cpDraws[3]
            local cpTitleBar = cpDraws[4]
            local cpLabel = cpDraws[5]
            cpDraws[6].Visible = false

            local cpPos = Vector2.new(self.x + self.w + self._padding * 2, self.y)
            local cpSize = Vector2.new(200, 170 + self._title_h)

            cpBase.Position = cpPos
            cpBase.Size = cpSize
            cpBase.Transparency = baseOpacity
            cpBase.Visible = childrenVisible
            cpBase.Color = self._color_surface
            cpCrust.Position = cpPos
            cpCrust.Size = cpSize
            cpCrust.Transparency = baseOpacity
            cpCrust.Visible = childrenVisible
            cpCrust.Color = self._color_crust
            cpBorder.Position = cpPos + Vector2.new(1,1)
            cpBorder.Size = cpSize - Vector2.new(2,2)
            cpBorder.Transparency = baseOpacity
            cpBorder.Visible = childrenVisible
            cpBorder.Color = self._color_border
            cpTitleBar.Position = cpPos + Vector2.new(1,1)
            cpTitleBar.Size = Vector2.new(cpSize.x - 2, self._title_h - 3)
            cpTitleBar.Transparency = baseOpacity
            cpTitleBar.Visible = childrenVisible
            cpTitleBar.Color = self._color_border
            cpLabel.Position = cpPos + Vector2.new(self._padding, self._padding)
            cpLabel.Transparency = baseOpacity
            cpLabel.Visible = childrenVisible
            cpLabel.Color = self._color_text

            local palletePos = cpPos + Vector2.new(self._padding, self._title_h + self._padding)
            local palleteSize = cpSize.y - self._title_h - self._padding * 2

            for i = 1, self._gradient_detail do
                local seg = cpDraws[6 + i]
                local step = 1 - (i - 1) / (self._gradient_detail - 1)
                seg.Size = Vector2.new(palleteSize * step, palleteSize)
                seg.Position = palletePos
                local h = clamp((self._active_colorpicker._slider_y) / palleteSize, 0, 1)
                seg.Color = Color3.fromHSV(h, step, 1)
                seg.Transparency = baseOpacity
                seg.Visible = childrenVisible
            end
            for i = 1, self._gradient_detail do
                local seg = cpDraws[6 + self._gradient_detail + i]
                local step = 1 - i / self._gradient_detail
                seg.Size = Vector2.new(palleteSize, palleteSize * step)
                seg.Position = palletePos + Vector2.new(0, palleteSize * (1 - step))
                seg.Color = black
                seg.Transparency = baseOpacity * 1 / (self._gradient_detail / 3)
                seg.Visible = childrenVisible
            end

            local hueSliderWidth = cpSize.x - palleteSize - self._padding * 4
            local hueSliderPos = palletePos + Vector2.new(cpSize.x - hueSliderWidth - self._padding * 2.5, 0)
            for i = 1, self._gradient_detail do
                local seg = cpDraws[6 + self._gradient_detail * 2 + i]
                local step = 1 - (i - 1) / self._gradient_detail
                seg.Size = Vector2.new(hueSliderWidth, palleteSize * step)
                seg.Position = hueSliderPos
                seg.Color = Color3.fromHSV(step, 1, 1)
                seg.Transparency = baseOpacity
                seg.Visible = childrenVisible
            end

            local drawsOffset = 6 + self._gradient_detail * 3
            local cpCursorBasePrimary    = cpDraws[drawsOffset + 1]
            local cpCursorCrustPrimary   = cpDraws[drawsOffset + 2]
            local cpCursorBaseSecondary  = cpDraws[drawsOffset + 3]
            local cpCursorCrustSecondary = cpDraws[drawsOffset + 4]
            local cpCursorBorderSecondary = cpDraws[drawsOffset + 5]

            if m1Held then
                if UILib._IsMouseWithinBounds(palletePos, Vector2.new(palleteSize, palleteSize)) then
                    self._active_colorpicker._pallete_pos = mousePos
                elseif UILib._IsMouseWithinBounds(hueSliderPos, Vector2.new(hueSliderWidth, palleteSize)) then
                    self._active_colorpicker._slider_y = mousePos.y - palletePos.y
                end
            end

            local palleteP = self._active_colorpicker._pallete_pos or palletePos
            local sliderP = hueSliderPos + Vector2.new(-2, self._active_colorpicker._slider_y)

            local relPalleteP = Vector2.new(
                clamp((palleteP.x - palletePos.x) / palleteSize, 0, 1),
                clamp((palleteP.y - palletePos.y) / palleteSize, 0, 1)
            )
            local relSliderP = clamp((self._active_colorpicker._slider_y) / palleteSize, 0, 1)
            local newColor = color3fromHSV(relSliderP, relPalleteP.x, 1 - relPalleteP.y)

            if m1Held and self._active_colorpicker.callback then
                self._active_colorpicker.callback(newColor)
            end

            cpCursorBasePrimary.Position = palleteP
            cpCursorBasePrimary.Color = self._color_text
            cpCursorBasePrimary.Visible = childrenVisible
            cpCursorCrustPrimary.Position = palleteP
            cpCursorCrustPrimary.Color = self._color_crust
            cpCursorCrustPrimary.Visible = childrenVisible

            local sliderCursorSize = Vector2.new(hueSliderWidth + 4, 4)
            cpCursorBaseSecondary.Size = sliderCursorSize
            cpCursorBaseSecondary.Position = sliderP
            cpCursorBaseSecondary.Color = self._color_surface
            cpCursorBaseSecondary.Visible = childrenVisible
            cpCursorCrustSecondary.Size = sliderCursorSize
            cpCursorCrustSecondary.Position = sliderP
            cpCursorCrustSecondary.Color = self._color_crust
            cpCursorCrustSecondary.Visible = childrenVisible
            cpCursorBorderSecondary.Size = sliderCursorSize + Vector2.new(-2,-2)
            cpCursorBorderSecondary.Position = sliderP + Vector2.new(1,1)
            cpCursorBorderSecondary.Color = self._color_border
            cpCursorBorderSecondary.Visible = childrenVisible

            if clickFrame and not UILib._IsMouseWithinBounds(cpPos, cpSize) then
                self:_RemoveColorpicker()
            end
            clickFrame = false
        end

        if self._active_dropdown then
            local ddChoices  = self._active_dropdown.choices
            local ddIsMulti  = self._active_dropdown.multi
            local ddCallback = self._active_dropdown.callback
            local ddPosition = self._active_dropdown.position
            local ddWidth    = self._active_dropdown.w
            local ddDraws    = self._active_dropdown._drawings

            local ddBase = ddDraws[1]
            local ddCrust = ddDraws[2]
            local ddBorder = ddDraws[3]
            local totalDDY = self._padding
            local ddCancel = clickFrame
            local i = 1
            for choice, choiceValue in pairs(ddChoices) do
                local _cW, cH = UILib._GetTextBounds(choice)
                local cDraw = ddDraws[3 + i]
                if not cDraw then
                    ddCancel = true
                else
                local cPos = ddPosition + Vector2.new(self._padding, totalDDY)
                local cSize = Vector2.new(ddWidth, cH + self._padding)
                cDraw.Position = cPos
                cDraw.Color = choiceValue and self._color_accent or self._color_text
                cDraw.Text = choice
                cDraw.Visible = childrenVisible

                if clickFrame and UILib._IsMouseWithinBounds(cPos, cSize) then
                    ddCancel = not ddIsMulti
                    if not ddIsMulti then
                        for cN, _ in pairs(ddChoices) do ddChoices[cN] = false end
                        ddChoices[choice] = true
                    else
                        ddChoices[choice] = not choiceValue
                    end
                    if ddCallback then
                        local retVal = {}
                        for cN, cV in pairs(ddChoices) do
                            if cV == true then table.insert(retVal, cN) end
                        end
                        ddCallback(retVal)
                    end
                end
                end
                totalDDY = totalDDY + cH * 2 + self._padding
                i = i + 1
            end

            if ddCancel then
                self:_RemoveDropdown()
            else
                ddBase.Position = ddPosition
                ddBase.Size = Vector2.new(ddWidth, totalDDY)
                ddBase.Transparency = baseOpacity
                ddBase.Visible = childrenVisible
                ddBase.Color = self._color_surface
                ddCrust.Position = ddPosition
                ddCrust.Size = Vector2.new(ddWidth, totalDDY)
                ddCrust.Transparency = baseOpacity
                ddCrust.Visible = childrenVisible
                ddCrust.Color = self._color_crust
                ddBorder.Position = ddPosition + Vector2.new(1,1)
                ddBorder.Size = Vector2.new(ddWidth-2, totalDDY-2)
                ddBorder.Transparency = baseOpacity
                ddBorder.Visible = childrenVisible
                ddBorder.Color = self._color_border
            end
            clickFrame = false
        end

        local uiCrust  = self._tree._drawings[1]
        local uiBorder = self._tree._drawings[2]
        local uiBase   = self._tree._drawings[3]
        local uiNavbar = self._tree._drawings[4]
        local uiTitle = self._tree._drawings[5]

        uiBase.Position = Vector2.new(self.x, self.y)
        uiBase.Size = Vector2.new(self.w, self.h)
        uiBase.Transparency = baseOpacity
        uiBase.Visible = childrenVisible
        uiBase.Color = self._color_surface
        uiBorder.Position = Vector2.new(self.x+1, self.y+1)
        uiBorder.Size = Vector2.new(self.w-2, self.h-2)
        uiBorder.Transparency = baseOpacity
        uiBorder.Visible = childrenVisible
        uiBorder.Color = self._color_border
        uiCrust.Position = Vector2.new(self.x, self.y)
        uiCrust.Size = Vector2.new(self.w, self.h)
        uiCrust.Transparency = baseOpacity
        uiCrust.Visible = childrenVisible
        uiCrust.Color = self._color_crust
        uiNavbar.Position = Vector2.new(self.x+2, self.y+2)
        uiNavbar.Size = Vector2.new(self.w-4, self._title_h-4)
        uiNavbar.Transparency = baseOpacity
        uiNavbar.Visible = childrenVisible
        uiNavbar.Color = self._color_border
        local _tW, titleH = UILib._GetTextBounds('')
        uiTitle.Position = Vector2.new(self.x+7, self.y + self._title_h/2 - titleH + 2)
        uiTitle.Transparency = baseOpacity
        uiTitle.Visible = false
        uiTitle.Color = self._color_text

        if self._title_chars then
            self._title_hue = (self._title_hue + deltaTime * 0.18) % 1
            local charWidth = fontSize * 0.72
            local baseX = self.x + 7
            local baseY = self.y + self._title_h/2 - titleH + 2
            local charCount = #self._title_chars
            for charIndex, charDrawing in ipairs(self._title_chars) do
                local hue = (self._title_hue + (charIndex - 1) / charCount * 0.55) % 1
                charDrawing.Position = Vector2.new(baseX + (charIndex - 1) * charWidth, baseY)
                charDrawing.Color = Color3.fromHSV(hue, 1, 1)
                charDrawing.Transparency = baseOpacity
                charDrawing.Visible = childrenVisible
            end
        end

        if self._rb then
            self._rainbow_hue = (self._rainbow_hue + deltaTime * 0.09) % 1
            local x, y, width, height = self.x, self.y, self.w, self.h
            local segmentCount = #self._rb
            local perimeter = 2 * (width + height)
            local function pointOnBorder(t)
                local d = (t % 1) * perimeter
                if d < width then
                    return Vector2.new(x + d, y)
                elseif d < width + height then
                    return Vector2.new(x + width, y + (d - width))
                elseif d < 2*width + height then
                    return Vector2.new(x + width - (d - width - height), y + height)
                else
                    return Vector2.new(x, y + height - (d - 2*width - height))
                end
            end
            local _spotFrac = 0.30
            for index = 1, segmentCount do
                local segment = self._rb[index]
                local startT = (self._rainbow_hue + (index-1)/segmentCount * _spotFrac) % 1
                local endT = (self._rainbow_hue + index/segmentCount * _spotFrac) % 1
                local alpha = math.sin(math.pi * (index - 0.5) / segmentCount)
                segment.From = pointOnBorder(startT)
                segment.To = pointOnBorder(endT)
                segment.Color = Color3.fromHSV(self._rainbow_hue, 1, 1)
                segment.Transparency = 1 - alpha * baseOpacity
                segment.Visible = childrenVisible
            end
        end

        local titleOrigin = Vector2.new(self.x, self.y)
        local titleSize = Vector2.new(self.w, self._title_h)
        if UILib._IsMouseWithinBounds(titleOrigin, titleSize) then
            if clickFrame then
                self._dragging = true
                self._drag_offset = mousePos - titleOrigin
            end
        end
        if self._dragging then
            if m1Held then
                self.x = mousePos.x - self._drag_offset.x
                self.y = mousePos.y - self._drag_offset.y
            else
                self._dragging = false
            end
            clickFrame = false
        end

        for _, tab in ipairs(self._tree._tabs) do
            for _, section in ipairs(tab._sections) do
                for _, keybind in ipairs(section._items) do
                    local itemType = keybind.type
                    local itemValue = keybind.value
                    local itemCallback = keybind.callback
                    if itemType == 'key' then
                        if itemValue and itemValue ~= 'unbound' and itemCallback then
                            local keyMode = keybind.mode
                            local keyState = keybind._state
                            if keyMode == 'Hold' then
                                keyState = self._inputs[itemValue].held
                            elseif keyMode == 'Toggle' and self._inputs[itemValue].click then
                                keyState = not keyState
                            elseif keyMode == 'Always' then
                                keyState = true
                            end
                            if keyState ~= keybind._state then
                                itemCallback(keyState)
                                keybind._state = keyState
                            end
                        end
                    end
                end
            end
        end

        local numTabs = #self._tree._tabs
        for tabIndex, tab in ipairs(self._tree._tabs) do
            local tabName   = tab.name
            local tabDraws  = tab._drawings
            local tabOpen   = self._active_tab == tabName

            local tabBackdrop = tabDraws[1]
            local tabShadow = tabDraws[2]
            local tabCursor   = tabDraws[3]
            local tabText   = tabDraws[4]

            local tabW = (self.w - self._padding * 2 - (numTabs - 1) * 2) / numTabs
            local tabH = self._tab_h
            local tabPosition = Vector2.new(self.x + self._padding + (tabIndex - 1) * (tabW + 2), self.y + self._title_h + self._padding)
            local tabSize = Vector2.new(tabW, tabH)

            tabBackdrop.Position = tabPosition
            tabBackdrop.Size = tabSize
            tabBackdrop.Transparency = baseOpacity
            tabBackdrop.Visible = childrenVisible
            tabBackdrop.Color = self._color_border
            tabShadow.Position = tabPosition + Vector2.new(0, tabH - 8)
            tabShadow.Size = Vector2.new(tabW, 8)
            tabShadow.Transparency = 0.05 * baseOpacity
            tabShadow.Visible = childrenVisible
            tabCursor.Position = tabPosition
            tabCursor.Size = Vector2.new(tabW, 1)
            tabCursor.Transparency = baseOpacity
            tabCursor.Visible = tabOpen and childrenVisible
            tabCursor.Color = self._color_accent
            tabText.Position = tabPosition + Vector2.new(4, tabH / 2 - fontSize / 2)
            tabText.Transparency = baseOpacity
            tabText.Visible = childrenVisible
            tabText.Color = self._color_text

            if clickFrame and UILib._IsMouseWithinBounds(tabPosition, tabSize) then
                self._active_tab = tabName
            end

            if tabOpen then
                local totalSectionH_0 = self._padding
                local totalSectionH_1 = self._padding

                for sectionIndex, section in ipairs(tab._sections) do
                    local sectionDraws = section._drawings
                    local sectionItems = section._items

                    local sectionY = self._padding * 2
                    local opposite = (sectionIndex + 1) % 2
                    local sectionW = self.w / 2 - self._padding * 1.5
                    local sectionPos = Vector2.new(
                        self.x + self._padding + self._padding * opposite + sectionW * opposite,
                        self.y + self._title_h + self._tab_h + self._padding * 2 + (opposite==1 and totalSectionH_0 or totalSectionH_1)
                    )

                    for _, sectionItem in ipairs(sectionItems) do
                        local itemType     = sectionItem.type
                        local itemDraws    = sectionItem._drawings
                        local itemValue    = sectionItem.value
                        local itemCallback = sectionItem.callback
                        local itemPosition = sectionPos + Vector2.new(10, sectionY)

                        if itemType == 'checkbox' then
                            local checkboxOutline = itemDraws[1]
                            local checkboxCheck  = itemDraws[2]
                            local checkboxShadow  = itemDraws[3]
                            local checkboxLabel  = itemDraws[4]

                            local boxSize = Vector2.new(14, 14)
                            checkboxOutline.Position = itemPosition
                            checkboxOutline.Size = boxSize
                            checkboxOutline.Transparency = baseOpacity
                            checkboxOutline.Visible = childrenVisible
                            checkboxCheck.Position = itemPosition + Vector2.new(1,1)
                            checkboxCheck.Size = boxSize - Vector2.new(2,2)
                            checkboxCheck.Transparency = baseOpacity
                            checkboxCheck.Visible = itemValue == true and childrenVisible
                            checkboxCheck.Color = self._color_accent
                            checkboxShadow.Position = itemPosition + Vector2.new(1, boxSize.y - 2)
                            checkboxShadow.Size = Vector2.new(boxSize.x - 2, 1)
                            checkboxShadow.Transparency = 0.3 * baseOpacity
                            checkboxShadow.Visible = itemValue == true and childrenVisible
                            checkboxShadow.Color = self._color_border
                            checkboxLabel.Position = itemPosition + Vector2.new(boxSize.x + 8, 0)
                            checkboxLabel.Transparency = baseOpacity
                            checkboxLabel.Visible = childrenVisible
                            checkboxLabel.Color = sectionItem._labelColor or self._color_text

                            if UILib._IsMouseWithinBounds(itemPosition, boxSize) then
                                checkboxOutline.Color = self._color_accent
                                if clickFrame then
                                    sectionItem.value = not sectionItem.value
                                    if itemCallback then itemCallback(sectionItem.value) end
                                end
                            else
                                checkboxOutline.Color = self._color_crust
                            end
                            sectionY = sectionY + boxSize.y + 8

                        elseif itemType == 'button' then
                            local btnOutline = itemDraws[1]
                            local btnFill   = itemDraws[2]
                            local btnShadow  = itemDraws[3]
                            local btnText   = itemDraws[4]

                            local btnLabel  = sectionItem.label or 'Button'
                            local btnTextW, btnTextH = UILib._GetTextBounds(btnLabel)
                            local btnW = sectionW - self._padding * 4
                            local btnH = 18
                            local btnSize = Vector2.new(btnW, btnH)

                            local isHovered = UILib._IsMouseWithinBounds(itemPosition, btnSize)
                            local isHeld    = sectionItem._held

                            btnOutline.Position = itemPosition
                            btnOutline.Size = btnSize
                            btnOutline.Transparency = baseOpacity
                            btnOutline.Visible = childrenVisible
                            btnOutline.Color = isHovered and self._color_accent or self._color_crust

                            btnFill.Position = itemPosition + Vector2.new(1, 1)
                            btnFill.Size = btnSize - Vector2.new(2, 2)
                            btnFill.Transparency = baseOpacity
                            btnFill.Visible = childrenVisible
                            btnFill.Color = isHeld and self._color_accent or self._color_border

                            btnShadow.Position = itemPosition + Vector2.new(1, btnH - 2)
                            btnShadow.Size = Vector2.new(btnW - 2, 2)
                            btnShadow.Transparency = 0.25 * baseOpacity
                            btnShadow.Visible = childrenVisible

                            btnText.Position = itemPosition + Vector2.new(btnW / 2 - btnTextW / 2, btnH / 2 - btnTextH / 2)
                            btnText.Text = btnLabel
                            btnText.Transparency = baseOpacity
                            btnText.Visible = childrenVisible
                            btnText.Color = isHovered and self._color_accent or self._color_text

                            if isHovered then
                                if m1Held then
                                    sectionItem._held = true
                                else
                                    if sectionItem._held then sectionItem._held = false end
                                end
                                if clickFrame and itemCallback then
                                    itemCallback()
                                    clickFrame = false
                                end
                            else
                                sectionItem._held = false
                            end
                            sectionY = sectionY + btnH + 6

                        elseif itemType == 'slider' then
                            local sliderOutline    = itemDraws[1]
                            local sliderFill       = itemDraws[2]
                            local sliderFillShadow = itemDraws[3]
                            local sliderValueText  = itemDraws[4]
                            local sliderLabel = itemDraws[5]

                            local min = sectionItem.min
                            local max = sectionItem.max
                            local step = sectionItem.step
                            local appendix = sectionItem.appendix
                            local sliderW = sectionW - self._padding * 3
                            local sliderH = 20
                            local sliderBoxSize = Vector2.new(sliderW, sliderH)
                            local _lW, labelH = UILib._GetTextBounds('')

                            sliderLabel.Position = itemPosition
                            sliderLabel.Transparency = baseOpacity
                            sliderLabel.Visible = childrenVisible
                            sliderLabel.Color = self._color_text
                            sliderOutline.Position = itemPosition + Vector2.new(0, labelH + 10)
                            sliderOutline.Size = sliderBoxSize
                            sliderOutline.Transparency = baseOpacity
                            sliderOutline.Visible = childrenVisible
                            sliderOutline.Color = self._color_crust

                            local fillPercent = (itemValue - min) / (max - min)
                            fillPercent = clamp(fillPercent, 0, 1)
                            local fillVisible = itemValue ~= min and childrenVisible
                            sliderFill.Position = itemPosition + Vector2.new(1, labelH + 11)
                            sliderFill.Size = Vector2.new(math.max(sliderW * fillPercent - 2, 0), sliderH - 2)
                            sliderFill.Transparency = baseOpacity
                            sliderFill.Visible = fillVisible
                            sliderFill.Color = self._color_accent
                            sliderFillShadow.Position = itemPosition + Vector2.new(1, labelH + sliderH + 7)
                            sliderFillShadow.Size = Vector2.new(math.max(sliderW * fillPercent - 2, 0), 2)
                            sliderFillShadow.Transparency = 0.15 * baseOpacity
                            sliderFillShadow.Visible = fillVisible

                            local displayedValue = tostring(math.floor(itemValue)) .. (appendix or '')
                            local sliderValueW, sliderValueH = UILib._GetTextBounds(displayedValue)
                            sliderValueText.Position = itemPosition + Vector2.new(sliderW - sliderValueW - 6, sliderValueH / 2 + sliderH - 2)
                            sliderValueText.Text = displayedValue
                            sliderValueText.Transparency = baseOpacity
                            sliderValueText.Visible = childrenVisible

                            if UILib._IsMouseWithinBounds(itemPosition + Vector2.new(0, labelH + 10), sliderBoxSize) then
                                sliderValueText.Color = self._color_accent
                                if m1Held then
                                    local mouseX = mousePos.x - itemPosition.x
                                    local percent = clamp(mouseX / sliderW, 0, 1)
                                    local newValue = min + (max - min) * percent
                                    newValue = math.floor((newValue / step) + 0.5) * step
                                    newValue = math.max(min, math.min(max, newValue))
                                    if newValue ~= sectionItem.value then
                                        sectionItem.value = newValue
                                        if itemCallback then itemCallback(newValue) end
                                    end
                                end
                            else
                                sliderValueText.Color = self._color_text
                            end
                            sectionY = sectionY + sliderH + 18 + labelH

                        elseif itemType == 'choice' then
                            local choiceOutline = itemDraws[1]
                            local choiceFill   = itemDraws[2]
                            local choiceValues  = itemDraws[3]
                            local choiceExpand = itemDraws[4]
                            local choiceLabel = itemDraws[5]
                            local choices = sectionItem.choices
                            local multi = sectionItem.multi
                            local _lW, labelH = UILib._GetTextBounds('')
                            local choiceW = sectionW - self._padding * 3
                            local choiceH = 20
                            local choiceBoxSize = Vector2.new(choiceW, choiceH)
                            local choiceBoxPosition = itemPosition + Vector2.new(0, labelH + 10)

                            choiceLabel.Position = itemPosition
                            choiceLabel.Transparency = baseOpacity
                            choiceLabel.Visible = childrenVisible
                            choiceLabel.Color = self._color_text

                            local valuesText = table.concat(itemValue, ', ')
                            local valuesTextW = UILib._GetTextBounds(valuesText)
                            choiceValues.Position = itemPosition + Vector2.new(4, labelH / 2 + choiceH - 2)
                            choiceValues.Text = valuesTextW > choiceW - 32 and '...' or valuesText
                            choiceValues.Transparency = baseOpacity
                            choiceValues.Visible = childrenVisible
                            choiceValues.Color = self._color_text

                            choiceOutline.Position = choiceBoxPosition
                            choiceOutline.Size = choiceBoxSize
                            choiceOutline.Transparency = baseOpacity
                            choiceOutline.Visible = childrenVisible
                            choiceFill.Position = choiceBoxPosition + Vector2.new(2,2)
                            choiceFill.Size = choiceBoxSize - Vector2.new(4,4)
                            choiceFill.Transparency = baseOpacity
                            choiceFill.Visible = childrenVisible
                            choiceFill.Color = self._color_crust

                            local expandSymbol = '<'
                            local choiceExpandW, choiceExpandH = UILib._GetTextBounds(expandSymbol)
                            choiceExpand.Position = itemPosition + Vector2.new(choiceW - choiceExpandW - 4, choiceExpandH / 2 + choiceH - 2)
                            choiceExpand.Text = expandSymbol
                            choiceExpand.Transparency = baseOpacity
                            choiceExpand.Visible = childrenVisible
                            choiceExpand.Color = self._color_text

                            if UILib._IsMouseWithinBounds(choiceBoxPosition, choiceBoxSize) then
                                choiceOutline.Color = self._color_accent
                                if clickFrame then
                                    local ddCB = function(newValues)
                                        sectionItem.value = newValues
                                        if itemCallback then itemCallback(sectionItem.value) end
                                    end
                                    self:_SpawnDropdown(itemValue, choices, multi, ddCB, choiceBoxPosition + Vector2.new(0, choiceH), choiceW)
                                end
                            else
                                choiceOutline.Color = self._color_crust
                            end
                            sectionY = sectionY + choiceH + 18 + labelH

                        elseif itemType == 'colorpicker' then
                            local cpOutline = itemDraws[1]
                            local cpFill   = itemDraws[2]
                            local cpShadow  = itemDraws[3]
                            local cpLabel  = itemDraws[4]

                            local boxSize = Vector2.new(30, 14)
                            local boxPosition = itemPosition + Vector2.new(sectionW - boxSize.x - self._padding * 3, 0)
                            cpOutline.Position = boxPosition
                            cpOutline.Size = boxSize
                            cpOutline.Transparency = baseOpacity
                            cpOutline.Visible = childrenVisible
                            cpOutline.Color = self._color_crust
                            cpFill.Position = boxPosition + Vector2.new(1,1)
                            cpFill.Size = boxSize - Vector2.new(2,2)
                            cpFill.Transparency = baseOpacity
                            local colorValue = sectionItem.value
                            if type(colorValue) == "table" then
                                cpFill.Color = Color3.fromRGB(unpack(colorValue))
                            else
                                cpFill.Color = colorValue
                            end
                            cpFill.Visible = childrenVisible
                            cpShadow.Position = boxPosition + Vector2.new(4,4)
                            cpShadow.Size = boxSize - Vector2.new(8,8)
                            cpShadow.Transparency = baseOpacity * 0.25
                            cpShadow.Visible = childrenVisible
                            cpLabel.Position = itemPosition
                            cpLabel.Transparency = baseOpacity
                            cpLabel.Visible = childrenVisible
                            cpLabel.Color = self._color_text

                            if UILib._IsMouseWithinBounds(boxPosition, boxSize) then
                                if clickFrame then
                                    local cpCB = function(newColor)
                                        sectionItem.value = newColor
                                        if itemCallback then itemCallback(Color3.fromRGB(unpack(sectionItem.value))) end
                                    end
                                    self:_SpawnColorpicker(sectionItem.value, sectionItem.label, cpCB)
                                elseif ctxFrame then
                                    self:_SpawnDropdown({}, {'Copy', 'Paste'}, false, function(values)
                                        local action = values[1]
                                        if action == 'Copy' then
                                            self._clipboard_color = itemValue
                                        elseif action == 'Paste' then
                                            sectionItem.value = self._clipboard_color or itemValue
                                            if itemCallback then itemCallback(Color3.fromRGB(unpack(sectionItem.value))) end
                                        end
                                    end, mousePos, 60)
                                end
                            end
                            sectionY = sectionY + boxSize.y + 10

                        elseif itemType == 'label' then
                            local label = itemDraws[1]
                            label.Position = itemPosition
                            label.Text = itemValue
                            label.Transparency = baseOpacity
                            label.Visible = childrenVisible
                            label.Color = (itemValue == '---') and self._color_overlay or self._color_text
                            sectionY = sectionY + fontSize + 6

                        elseif itemType == 'key' then
                            local keyLabel   = itemDraws[1]
                            local keyOutline = itemDraws[2]
                            local keyFill    = itemDraws[3]
                            local keyText    = itemDraws[4]

                            local buttonText = sectionItem._listening == true and '...' or itemValue:upper()
                            local buttonTextW, buttonTextH = UILib._GetTextBounds(buttonText)
                            local buttonBoxSize = Vector2.new(buttonTextW + self._padding * 2, 20)
                            local buttonPosition = itemPosition + Vector2.new(sectionW - buttonBoxSize.x - self._padding * 3, 0)

                            keyText.Position = buttonPosition + Vector2.new(self._padding, 4)
                            keyText.Transparency = baseOpacity
                            keyText.Text = buttonText
                            keyText.Visible = childrenVisible
                            keyText.Color = self._color_text
                            keyOutline.Position = buttonPosition
                            keyOutline.Size = buttonBoxSize
                            keyOutline.Transparency = baseOpacity
                            keyOutline.Visible = childrenVisible
                            keyFill.Position = buttonPosition + Vector2.new(2,2)
                            keyFill.Size = buttonBoxSize - Vector2.new(4,4)
                            keyFill.Transparency = baseOpacity
                            keyFill.Visible = childrenVisible
                            keyFill.Color = self._color_crust
                            keyLabel.Position = itemPosition + Vector2.new(0, buttonTextH / 2 + 1)
                            keyLabel.Transparency = baseOpacity
                            keyLabel.Visible = childrenVisible
                            keyLabel.Color = self._color_text

                            if UILib._IsMouseWithinBounds(buttonPosition, buttonBoxSize) then
                                if clickFrame then
                                    sectionItem._listening = true
                                    self._inputs.m1.click = false
                                end
                                keyOutline.Color = self._color_accent
                            else
                                keyOutline.Color = self._color_crust
                            end

                            if sectionItem._listening then
                                for keycode, inputData in pairs(self._inputs) do
                                    if inputData.click then
                                        sectionItem.value = keycode
                                        sectionItem._listening = false
                                        if itemCallback then itemCallback(keycode) end
                                        break
                                    end
                                end
                            end
                            sectionY = sectionY + 22 + buttonTextH
                        end
                    end

                    local sectionBackdrop = sectionDraws[1]
                    local sectionCrust  = sectionDraws[2]
                    local sectionBorder   = sectionDraws[3]
                    local sectionTitle  = sectionDraws[4]

                    sectionCrust.Position = sectionPos
                    sectionCrust.Size = Vector2.new(sectionW, sectionY)
                    sectionCrust.Transparency = baseOpacity
                    sectionCrust.Visible = childrenVisible
                    sectionCrust.Color = self._color_crust
                    sectionBorder.Position = sectionPos + Vector2.new(1,1)
                    sectionBorder.Size = Vector2.new(sectionW-2, sectionY-2)
                    sectionBorder.Transparency = baseOpacity
                    sectionBorder.Visible = childrenVisible
                    sectionBorder.Color = self._color_overlay
                    local _, sectionTitleH = UILib._GetTextBounds('')
                    sectionTitle.Position = sectionPos + Vector2.new(10, -sectionTitleH / 2)
                    sectionTitle.Transparency = baseOpacity
                    sectionTitle.Visible = childrenVisible
                    sectionTitle.Color = self._color_text
                    sectionBackdrop.Visible = false

                    sectionY = sectionY + self._padding
                    if opposite == 1 then
                        totalSectionH_0 = totalSectionH_0 + sectionY
                    else
                        totalSectionH_1 = totalSectionH_1 + sectionY
                    end
                end
            else
                for _, section in ipairs(tab._sections) do
                    hideDrawings(section._drawings)
                    for _, item in ipairs(section._items) do
                        hideDrawings(item._drawings)
                    end
                end
            end
        end

        self._tick = os.clock()
    end

    function UILib:Destroy()
        for _, drawing in pairs(self._tree._drawings) do
            drawing:Remove()
        end

        self:_RemoveDropdown()
        self:_RemoveColorpicker()

        if self._rb then
            for _, line in ipairs(self._rb) do
                line:Remove()
            end
        end

        if self._title_chars then
            for _, ch in ipairs(self._title_chars) do
                ch:Remove()
            end
        end

        for _, tab in pairs(self._tree._tabs) do
            if tab._drawings then
                for _, drawing in pairs(tab._drawings) do
                    drawing:Remove()
                end
            end

            if tab._sections then
                for _, section in pairs(tab._sections) do
                    for _, drawing in pairs(section._drawings) do
                        drawing:Remove()
                    end

                    if section._items then
                        for _, item in pairs(section._items) do
                            for _, drawing in pairs(item._drawings) do
                                drawing:Remove()
                            end
                        end
                    end
                end
            end
        end
        setrobloxinput(true)
    end

    return UILib
end
