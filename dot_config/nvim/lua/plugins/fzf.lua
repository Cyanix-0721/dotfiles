return {
  "ibhagwan/fzf-lua",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    local fzf = require("fzf-lua")
    fzf.setup({
      -- 在此处添加你的自定义配置
      -- 例如，设置文件搜索不忽略 .gitignore 中的文件
      files = {
        fd = "--no-ignore-vcs",
      },
      -- 更多配置项请参考 :help fzf-lua
    })
  end,
}
