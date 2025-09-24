local M = {}

function M.start(initcmdline)
  initcmdline = initcmdline or ""

  -- If starting from the cmdline, restart with the cmdline's value
  if initcmdline == "" and vim.fn.getcmdline() ~= "" then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<c-u>", true, false, true) .. "call SkyBison('" .. vim.fn.getcmdline() .. "')", "n", false)
    return
  end

  -- ensure we have room
  if vim.o.lines < 14 then
    vim.api.nvim_err_writeln("Insufficient lines for SkyBison output")
    return
  end

  -- store v:count here. In lua, we can get it with vim.v.count
  local vcount = vim.v.count

  -- set the initial g:skybison_numberselect setting for the session
  local numberselect = vim.g.skybison_numberselect
  if numberselect == nil then
    numberselect = 1
  end

  local saved_settings = {
    winsizecmd = vim.fn.winrestcmd(),
    initlaststatus = vim.o.laststatus,
    initshowmode = vim.o.showmode,
    initshellslash = vim.o.shellslash,
    initwinnr = vim.fn.winnr(),
    initwinheight = vim.o.winheight
  }

  local function cleanup(cmdline)
    vim.o.laststatus = saved_settings.initlaststatus
    vim.o.showmode = saved_settings.initshowmode
    vim.o.shellslash = saved_settings.initshellslash
    vim.o.winheight = saved_settings.initwinheight
    -- pcall(vim.cmd, 'hide') -- This is no longer needed for floating windows
    vim.cmd(saved_settings.initwinnr .. "wincmd w")
    vim.cmd(saved_settings.winsizecmd)
    vim.cmd("redraw")

    if cmdline and cmdline ~= "" then
      pcall(vim.cmd, cmdline)
      vim.fn.histadd(":", cmdline)
    end
  end

  local win_id = nil
  local function close_and_cleanup(cmdline)
    if win_id and vim.api.nvim_win_is_valid(win_id) then
      vim.api.nvim_win_close(win_id, true)
    end
    cleanup(cmdline)
  end

  -- Use pcall to make sure we always properly clean up.
  local status, result = pcall(function()
    -- set and save global settings to restore on exit
    vim.o.laststatus = 0
    vim.o.showmode = true
    vim.o.shellslash = true
    vim.o.winheight = 1

    -- Create a scratch buffer for the floating window
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = 'hide'
    vim.bo[buf].buftype = 'nofile'
    vim.bo[buf].swapfile = false

    -- Window configuration
    local width = vim.o.columns
    local height = 11
    local row = vim.o.lines - height
    local col = 0

    win_id = vim.api.nvim_open_win(buf, true, {
      relative = 'editor',
      width = width,
      height = height,
      row = row,
      col = col,
      style = 'minimal',
      border = 'none'
    })

    vim.wo[win_id].winhighlight = 'Normal:FloatBorder,CursorLine:PmenuSel'
    vim.wo[win_id].cursorline = true
    vim.wo[win_id].number = false
    vim.wo[win_id].relativenumber = false
    vim.wo[win_id].wrap = false

    local function update_ui()
      local cmdline = vim.api.nvim_buf_get_lines(buf, 10, 11, false)[1] or ":"
      cmdline = cmdline:sub(2)

      local vcount = vim.v.count

      -- get various aspects of the current cmdline
      local cmdline_terms = vim.fn.split(cmdline, '\\s\\+')
      if cmdline:sub(-1) == ' ' then
        table.insert(cmdline_terms, '')
      end
      
      local cmdline_head_terms = {}
      if #cmdline_terms > 1 then
        for i = 1, #cmdline_terms - 1 do
          table.insert(cmdline_head_terms, cmdline_terms[i])
        end
      end
      local cmdline_head = table.concat(cmdline_head_terms, ' ')
      
      local cmdline_tail = ""
      if #cmdline_terms > 0 then
        cmdline_tail = cmdline_terms[#cmdline_terms]
      end

      -- fuzz the cmdline
      local fuzzed_tail
      local fuzz_level = vim.g.skybison_fuzz or 0
      if fuzz_level == 1 then
        fuzzed_tail = cmdline_tail:gsub(".", "*%0")
      elseif fuzz_level == 2 then
        fuzzed_tail = cmdline_tail:gsub("([^/]+)", "*%1")
      else
        fuzzed_tail = cmdline_tail
      end

      if fuzzed_tail:sub(1, 2) == '*/' or fuzzed_tail:sub(1, 2) == '*.' then
        fuzzed_tail = fuzzed_tail:sub(2)
      end
      fuzzed_tail = fuzzed_tail:gsub("%*%.%*%.", "..")
      fuzzed_tail = fuzzed_tail:gsub("/%*%.", "/.")
      fuzzed_tail = fuzzed_tail:gsub("%%*|", "|")

      local fuzzed_cmdline
      if cmdline_head ~= '' then
        fuzzed_cmdline = cmdline_head .. ' ' .. fuzzed_tail
      elseif cmdline_tail ~= '' then
        fuzzed_cmdline = fuzzed_tail
      else
        fuzzed_cmdline = ''
      end

      -- Determine cmdline-completion options
      vim.cmd(saved_settings.initwinnr .. "wincmd w")
      local results = vim.fn.getcompletion(fuzzed_cmdline, 'cmdline')
      vim.api.nvim_set_current_win(win_id)

      -- output
      local numberselect = vim.g.skybison_numberselect
      if numberselect == nil then numberselect = 1 end

      local display_results = {}
      for i = 1, math.min(#results, 9) do
        if numberselect == 1 then
          table.insert(display_results, string.format("%d %s", i, results[i]))
        else
          table.insert(display_results, "· " .. results[i])
        end
      end

      local top_lines = {}
      for i = 1, 10 - #display_results do table.insert(top_lines, "") end
      for _, r in ipairs(display_results) do table.insert(top_lines, r) end
      
      if #results == 0 then
        top_lines[10] = "[No Results]"
      elseif #results > 9 then
        top_lines[10] = "-- more --"
      end

      vim.api.nvim_buf_set_lines(buf, 0, 10, false, top_lines)
    end

    local function setup_buffer_features()
      vim.api.nvim_create_autocmd("TextChangedI", {
        buffer = buf,
        callback = update_ui
      })

      vim.keymap.set('i', '<Esc>', function()
        close_and_cleanup("")
      end, { buffer = buf, nowait = true })

      vim.keymap.set('i', '<CR>', function()
        local line = vim.api.nvim_buf_get_lines(buf, 10, 11, false)[1] or ":"
        local final_cmdline = line:sub(2) -- strip leading ':'
        close_and_cleanup(final_cmdline)
      end, { buffer = buf, nowait = true })

      vim.keymap.set('i', '<Tab>', function()
        local line = vim.api.nvim_buf_get_lines(buf, 10, 11, false)[1] or ":"
        local cmdline = line:sub(2)
        local results = vim.fn.getcompletion(cmdline, 'cmdline')
        if #results > 0 then
          local first = results[1]
          local max_len = #first
          for i = 2, #results do
            local current = results[i]
            local len = 0
            for j = 1, math.min(#first, #current) do
              if first:sub(j, j) == current:sub(j, j) then
                len = len + 1
              else
                break
              end
            end
            if len < max_len then max_len = len end
          end
          local prefix = first:sub(1, max_len)

          local cmdline_terms = vim.fn.split(cmdline, '\\s\\+')
          local cmdline_head_terms = {}
          if #cmdline_terms > 1 then
            for j = 1, #cmdline_terms - 1 do
              table.insert(cmdline_head_terms, cmdline_terms[j])
            end
          end
          local cmdline_head = table.concat(cmdline_head_terms, ' ')
          
          local new_cmdline = cmdline_head .. (#cmdline_head > 0 and ' ' or '') .. prefix
          vim.api.nvim_buf_set_lines(buf, 10, 11, false, {":" .. new_cmdline})
          vim.api.nvim_win_set_cursor(win_id, {11, #new_cmdline + 1})
        end
      end, { buffer = buf, nowait = true })

      for i = 1, 9 do
        vim.keymap.set('i', tostring(i), function()
            local line = vim.api.nvim_buf_get_lines(buf, 10, 11, false)[1] or ":"
            local cmdline = line:sub(2)

            local cmdline_terms = vim.fn.split(cmdline, '\\s\\+')
            local cmdline_head_terms = {}
            if #cmdline_terms > 1 then
              for j = 1, #cmdline_terms - 1 do
                table.insert(cmdline_head_terms, cmdline_terms[j])
              end
            end
            local cmdline_head = table.concat(cmdline_head_terms, ' ')
            
            -- This is a bit simplified, but should work for now
            local results = vim.fn.getcompletion(cmdline, 'cmdline')
            if #results >= i then
              local new_cmdline = cmdline_head .. (#cmdline_head > 0 and ' ' or '') .. results[i]
              vim.api.nvim_buf_set_lines(buf, 10, 11, false, {":" .. new_cmdline})
              vim.api.nvim_win_set_cursor(win_id, {11, #new_cmdline + 1})
            end
        end, { buffer = buf, nowait = true })
      end
    end

    setup_buffer_features()

    -- Initialize buffer content
    local initial_lines = {}
    for i = 1, 10 do table.insert(initial_lines, "") end
    table.insert(initial_lines, ":" .. initcmdline)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, initial_lines)

    vim.api.nvim_set_current_win(win_id)
    vim.api.nvim_win_set_cursor(win_id, {height, #(":" .. initcmdline)})
    vim.cmd('startinsert!')
  end)

  if not status then
    vim.api.nvim_err_writeln("SkyBison: This error occurred: " .. vim.inspect(result))
    cleanup("")
  else
    -- cleanup is now handled by the keymaps
  end
end

return M
