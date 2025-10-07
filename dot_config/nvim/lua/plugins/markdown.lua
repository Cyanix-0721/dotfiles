return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    keys = {
      {
        "<leader>mp",
        function()
          require("render-markdown").toggle()
        end,
        desc = "预览 Markdown / Toggle Preview",
      },
    },
    opts = {
      heading = {
        enabled = true,
        sign = true,
        icons = { "󰉫 ", "󰉬 ", "󰉭 ", "󰉮 ", "󰉯 ", "󰉰 " },
      },
      bullet = { icons = { "•", "◦", "▪" } },
      code = { border = "rounded" },
      quote = { icon = "┃", repeat_linebreak = true },
      dash = { icon = "─" },
      pipe_table = { preset = "round" },
      link = { enabled = true, style = "italic" },
    },
    config = function(_, opts)
      local render = require("render-markdown")
      render.setup(opts)

      ----------------------------------------------------------------------
      -- 🚫 禁用 Neovim 内置拼写检查
      ----------------------------------------------------------------------
      vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter", "FileType" }, {
        pattern = "*.md",
        callback = function()
          vim.opt_local.spell = false
        end,
        group = vim.api.nvim_create_augroup("RenderMarkdownSpell", { clear = true }),
      })

      ----------------------------------------------------------------------
      -- 🧠 自动检测 Obsidian Vault 并渲染
      ----------------------------------------------------------------------
      local function in_obsidian_vault()
        local cwd = vim.fn.expand("%:p:h")
        while cwd ~= "/" do
          if vim.fn.isdirectory(cwd .. "/.obsidian") == 1 then
            return true
          end
          cwd = vim.fn.fnamemodify(cwd, ":h")
        end
        return false
      end

      vim.api.nvim_create_autocmd("BufReadPost", {
        pattern = "*.md",
        callback = function()
          if in_obsidian_vault() then
            vim.defer_fn(function()
              if not render.is_rendering() then
                render.enable()
              end
            end, 150)
          end
        end,
      })

      ----------------------------------------------------------------------
      -- 🔗 [[wiki-link]] 跳转
      ----------------------------------------------------------------------
      vim.keymap.set("n", "gf", function()
        local line = vim.api.nvim_get_current_line()
        local col = vim.fn.col(".")
        local before = line:sub(1, col)
        local match = before:match("%[%[([^%[%]]+)$")
        if not match then
          vim.cmd("normal! gf")
          return
        end

        local filename = match
        if not filename:match("%.md$") then
          filename = filename .. ".md"
        end

        local current_dir = vim.fn.expand("%:p:h")
        local target = current_dir .. "/" .. filename
        if vim.fn.filereadable(target) == 0 then
          local cwd = current_dir
          while cwd ~= "/" do
            if vim.fn.isdirectory(cwd .. "/.obsidian") == 1 then
              target = cwd .. "/" .. filename
              break
            end
            cwd = vim.fn.fnamemodify(cwd, ":h")
          end
        end

        if vim.fn.filereadable(target) == 1 then
          vim.cmd("edit " .. vim.fn.fnameescape(target))
        else
          vim.notify("未找到笔记：" .. filename, vim.log.levels.WARN)
        end
      end, { desc = "打开 Obsidian 链接 / Open wiki-link" })
    end,
  },
}
