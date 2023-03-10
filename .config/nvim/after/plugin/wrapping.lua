local status_ok, wrapping = pcall(require, 'wrapping')
if not status_ok then
  return
end

wrapping.setup()
