vim.api.nvim_create_user_command('SkyBison', function(opts)
  -- The vimscript version takes an initial commandline value.
  -- For now, we'll just call the main function without it.
  require('skybison').start(opts.args)
end, { nargs = '?' })
