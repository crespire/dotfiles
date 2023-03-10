local status_ok, lsp = pcall(require, 'lsp-zero')
if not status_ok then
  return
end

lsp.preset('recommended')

-- Configure LTeX
lsp.configure('ltex', {
  settings = {
    ltex = {
      disabledRules = {
        ['en'] = { 'PROFANITY' },
      },
    }
  }
})

lsp.setup()
