local status_ok, lsp = pcall(require, 'lsp-zero')
if not status_ok then
  return
end

vim.opt.signcolumn = 'yes'

lsp.preset('recommended')

-- Configure LTeX
lsp.configure('ltex', {
  settings = {
    ltex = {
      disabledRules = {
        ['en-US'] = { 'PROFANITY' },
      },
    },
  }
})

lsp.configure('yamlls', {
  settings = {
    yaml = {
      keyOrdering = false,
    }
  }
})

lsp.setup()
