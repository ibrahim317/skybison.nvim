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
    pcall(vim.cmd, 'hide')
    vim.cmd(saved_settings.initwinnr .. "wincmd w")
    vim.cmd(saved_settings.winsizecmd)
    vim.cmd("redraw")

    if cmdline and cmdline ~= "" then
      pcall(vim.cmd, cmdline)
      vim.fn.histadd(":", cmdline)
    end
  end

  -- Use pcall to make sure we always properly clean up.
  local status, result = pcall(function()
    -- set and save global settings to restore on exit
    vim.o.laststatus = 0
    vim.o.showmode = true
    vim.o.shellslash = true
    vim.o.winheight = 1

    -- setup output window
    vim.cmd("botright 11new")
    local sbwinnr = vim.fn.winnr()
    vim.cmd('normal "10oggzt"')
    for i = 1, 11 do
      vim.api.nvim_buf_set_lines(0, i - 1, i, false, {""})
    end
    vim.cmd("nohlsearch")
    vim.wo.cursorcolumn = false
    vim.wo.cursorline = false
    vim.wo.number = false
    vim.wo.wrap = false
    vim.bo.bufhidden = "delete"
    if vim.fn.exists("&relativenumber") == 1 then
      vim.wo.relativenumber = false
    end

    -- syntax highlighting
    vim.cmd('syntax match LineNr  /^[0-9·]/')
    vim.cmd('syntax match MoreMsg /^-.*/')
    vim.cmd('syntax match Comment /^\\[.*/')
    vim.cmd('syntax match Comment /^:.*_$/hs=e')

    -- remove any signs that could be placed in the output window
    local signs_output = vim.fn.execute('sign place buffer=' .. vim.api.nvim_get_current_buf())
    if #vim.fn.split(signs_output, '\\n') > 1 then
      vim.cmd("sign unplace * buffer=" .. vim.api.nvim_get_current_buf())
    end
    
    -- initialize other variables
    local cmdline = initcmdline
    local ctrlv = false
    local histnr = vim.fn.histnr(':') + 1
    local cmdline_newest = ""

    -- main loop
    while true do
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

      -- asterisks break some corner cases
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

      -- highlight cmdline_tail in results
      vim.cmd('syntax clear Identifier')
      if fuzzed_tail ~= '' then
        local escaped_tail = fuzzed_tail:gsub("[\\/]", "\\%0")
        if escaped_tail:sub(1, 1) == '*' then
          escaped_tail = escaped_tail:sub(2)
        end
        escaped_tail = escaped_tail:gsub("%*", "\\.\\*")
        vim.cmd('syntax match Identifier /\\V\\c' .. escaped_tail .. '/')
      end

      -- move focus back to previous window so buffer/window-specific items are properly completed
      vim.cmd(saved_settings.initwinnr .. "wincmd w")

      -- Determine cmdline-completion options
      local results = vim.fn.getcompletion(fuzzed_cmdline, 'cmdline')
      
      -- switch back to skybison window
      vim.cmd(sbwinnr .. "wincmd w")

      -- output
      -- clear buffer
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {})

      local counter = 1
      local linenumber = 10 - #results
      if #results > 1 and #results < 10 then
        linenumber = linenumber + 1
      end

      local display_results = {}
      for i = 1, math.min(#results, 9) do
        local result = results[i]
        if numberselect == 1 then
          table.insert(display_results, counter .. " " .. result)
        else
          table.insert(display_results, "· " .. result)
        end
        counter = counter + 1
      end
      vim.api.nvim_buf_set_lines(0, linenumber - #display_results, linenumber, false, display_results)
      
      if #results == 0 then
        vim.api.nvim_buf_set_lines(0, 9, 10, false, {"[No Results]"})
      elseif #results == 1 then
        if #cmdline_terms == vcount and vcount ~= 0 then
          cmdline = (cmdline_head ~= "" and (cmdline_head .. ' ') or "") .. results[1]
          break
        else
          if ctrlv then
            vim.api.nvim_buf_set_lines(0, 9, 10, false, {"Press <CR> to run cmdline as entered"})
          else
            vim.api.nvim_buf_set_lines(0, 9, 10, false, {'Press <CR> to select and run with "' .. results[1] .. '"'})
          end
        end
      elseif #results > 9 then
        vim.api.nvim_buf_set_lines(0, 9, 10, false, {"-- more --"})
      end

      if ctrlv then
        vim.api.nvim_buf_set_lines(0, 10, 11, false, {":" .. cmdline .. "^"})
      else
        vim.api.nvim_buf_set_lines(0, 10, 11, false, {":" .. cmdline .. "_"})
      end
      vim.cmd("redraw")

      -- get input from user
      local raw_input = vim.fn.getchar()
      local input
      if type(raw_input) == 'number' then
        input = vim.fn.nr2char(raw_input)
      else
        input = vim.api.nvim_replace_termcodes(raw_input, false, true, true)
      end

      -- process input
      if ctrlv then
        if input == "\r" then
          break
        end
        ctrlv = false
        cmdline = cmdline .. input
      elseif input == "\x1b" then -- <esc>
        cmdline = ""
        break
      elseif input == "\x16" then -- <c-v>
        ctrlv = true
      elseif input == "<BS>" or input == "<C-H>" or raw_input == "<80>kb" or input == "\x7f" or input == "\x08" then -- <bs> or <c-h>
        if #cmdline > 0 then
          cmdline = cmdline:sub(1, #cmdline - 1)
        end
      elseif input == "\x15" then -- <c-u>
        cmdline = ""
      elseif input == "\x17" then -- <c-w>
        if cmdline:sub(-1) == " " then
          cmdline = cmdline:sub(1, #cmdline -1)
        end
        while #cmdline > 0 and cmdline:sub(-1) ~= " " do
          cmdline = cmdline:sub(1, #cmdline -1)
        end
      elseif input == "\t" or input == "\x0c" then -- <tab> or <c-l>
        if #results > 0 then
          -- Find longest common prefix
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
            if len < max_len then
              max_len = len
            end
          end
          local prefix = first:sub(1, max_len)
          cmdline = (cmdline_head ~= "" and (cmdline_head .. ' ') or "") .. prefix
        end
      elseif input == "\r" then -- <cr>
        if #results == 1 then
          cmdline = (cmdline_head ~= "" and (cmdline_head .. ' ') or "") .. results[1]
        end
        break
      elseif input == "<Up>" or input == "\x10" or input == "k" then -- <c-p> or <up>
        if histnr > 0 then
          if histnr == vim.fn.histnr(':') + 1 then
            cmdline_newest = cmdline
          end
          histnr = histnr - 1
          cmdline = vim.fn.histget(':', histnr)
        end
      elseif input == "<Down>" or input == "\x0e" or input == "j" then -- <c-n> or <down>
        if histnr < vim.fn.histnr(':') then
          histnr = histnr + 1
          cmdline = vim.fn.histget(':', histnr)
        else
          histnr = vim.fn.histnr(':') + 1
          cmdline = cmdline_newest
        end
      elseif input == "\x07" then -- <c-g>
        numberselect = 1 - numberselect
      elseif tonumber(input) and numberselect == 1 and #results >= tonumber(input) then
          cmdline = cmdline_head .. ' ' .. results[tonumber(input)]
      else
        cmdline = cmdline .. input
      end
    end

    return cmdline
  end)

  if not status then
    vim.api.nvim_err_writeln("SkyBison: This error occurred: " .. vim.inspect(result))
    cleanup("")
  else
    cleanup(result)
  end
end

return M
