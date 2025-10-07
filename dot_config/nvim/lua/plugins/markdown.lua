return {
  {
    'MeanderingProgrammer/render-markdown.nvim',
    ft = { 'markdown' },
    dependencies = {
      'nvim-treesitter/nvim-treesitter',
      'nvim-tree/nvim-web-devicons',
    },
    keys = {
      {
        '<leader>mp',
        function()
          require('render-markdown').toggle()
        end,
        desc = 'Toggle Preview',
      },
    },
    opts = {
      heading = {
        enabled = true,
        sign = true,
        icons = { '󰉫 ', '󰉬 ', '󰉭 ', '󰉮 ', '󰉯 ', '󰉰 ' },
      },
      bullet = { icons = { '•', '◦', '▪' } },
      code = { border = 'rounded' },
      quote = { icon = '┃', repeat_linebreak = true },
      dash = { icon = '─' },
      pipe_table = { preset = 'round' },
      link = { enabled = true, style = 'italic' },
    },
    config = function(_, opts)
      local render = require('render-markdown')
      render.setup(opts)

      ----------------------------------------------------------------------
      -- 🧠 自动检测 Obsidian Vault 并渲染
      ----------------------------------------------------------------------
      local function in_obsidian_vault()
        local cwd = vim.fn.expand('%:p:h')
        while cwd ~= '/' do
          if vim.fn.isdirectory(cwd .. '/.obsidian') == 1 then
            return true
          end
          cwd = vim.fn.fnamemodify(cwd, ':h')
        end
        return false
      end

      vim.api.nvim_create_autocmd('BufReadPost', {
        pattern = '*.md',
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
    end,
  },
}
