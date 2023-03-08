local bufferline = require("bufferline")
bufferline.setup{
  options = {
    numbers = function(opts)
      return string.format('%s|%s', opts.id, opts.raise(opts.ordinal))
    end,
    separator_style = "thick",
    offsets = {
      {
        filetype = 'NvimTree',
        text = 'File Explorer',
        highlight = 'Directory',
        separator = true,
        text_align = 'center'
      }
    }
  }
}
