vim.api.nvim_create_user_command('SkyBison', function(opts)
  require('skybison').start(opts.fargs[1] or "")
end, { nargs = '?' })
