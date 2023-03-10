local status_ok, lsp = pcall(require, 'lsp-zero')
if not status_ok then
  return
end

vim.opt.signcolumn = 'yes'

local user_dict = {
  ['en-US'] = {vim.fn.expand('$HOME/.config/nvim/spell/en-us.conf')}
}

local function readFiles(files)
    local dict = {}
    for _,file in ipairs(files) do
        local f = io.open(file, "r")
        for l in f:lines() do
            table.insert(dict, l)
        end
    end
    return dict
end

lsp.preset('recommended')

-- Configure LTeX
lsp.configure('ltex', {
  settings = {
    ltex = {
      disabledRules = {
        ['en-US'] = { 'PROFANITY' },
      },
      dictionary = {
        ['en-US'] = readFiles(user_dict['en-US'] or {}),
      },
    },
  }
})

lsp.setup()
