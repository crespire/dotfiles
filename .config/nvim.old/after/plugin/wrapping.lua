local status_ok, wrapping = pcall(require, 'wrapping')
if not status_ok then
  return
end

wrapping.setup({
  notify_on_switch = false,
  softener = {
    markdown = function()
      return true
    end
  }
})
