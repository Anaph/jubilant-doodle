-- ~/.config/nvim/lua/plugins/dev.lua
-- Added by i3-desktop-setup (--extras / --neovim): Claude Code, git, and a
-- C/C++/CMake toolchain layered on top of NvChad. Files under lua/plugins/ are
-- auto-imported by the NvChad starter, so this spec loads automatically.
--
-- __NVCHAD_REPO__ is replaced at install time with the configured NvChad core.

-- Auto-open the file tree (nvim-tree) on startup, keeping focus in the editor.
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    vim.schedule(function()
      pcall(vim.cmd, "NvimTreeOpen")
      pcall(vim.cmd, "wincmd p")
    end)
  end,
})

-- Start clangd (C/C++) once, without clobbering NvChad's own lspconfig wiring.
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "c", "cpp", "objc", "objcpp", "cuda" },
  callback = function()
    if vim.g.__clangd_ready then
      return
    end
    vim.g.__clangd_ready = true
    local ok, lspconfig = pcall(require, "lspconfig")
    if not ok then
      return
    end
    local opts = {}
    local nok, nvlsp = pcall(require, "nvchad.configs.lspconfig")
    if nok then
      opts.on_attach = nvlsp.on_attach
      opts.on_init = nvlsp.on_init
      opts.capabilities = nvlsp.capabilities
    end
    pcall(function()
      lspconfig.clangd.setup(opts)
      vim.cmd("silent! LspStart clangd")
    end)
  end,
})

-- Optional CMake language server (install with: pipx install cmake-language-server).
vim.api.nvim_create_autocmd("FileType", {
  pattern = "cmake",
  callback = function()
    if vim.g.__cmakels_ready then
      return
    end
    vim.g.__cmakels_ready = true
    if vim.fn.executable("cmake-language-server") ~= 1 then
      return
    end
    local ok, lspconfig = pcall(require, "lspconfig")
    if not ok then
      return
    end
    pcall(function()
      lspconfig.cmake.setup({})
      vim.cmd("silent! LspStart cmake")
    end)
  end,
})

return {
  -- Use the configured NvChad core (defaults to the Anaph/NvChad fork, v2.5).
  { "NvChad/NvChad", url = "__NVCHAD_REPO__.git", branch = "v2.5" },

  -- Claude Code integration (needs the `claude` CLI on PATH).
  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    config = true,
    keys = {
      { "<leader>ac", "<cmd>ClaudeCode<cr>", desc = "Claude Code: toggle" },
      { "<leader>af", "<cmd>ClaudeCodeFocus<cr>", desc = "Claude Code: focus" },
      { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = { "n", "v" }, desc = "Claude Code: send" },
    },
  },

  -- Git.
  { "tpope/vim-fugitive", cmd = { "Git", "G", "Gdiffsplit", "Gblame" } },
  { "sindrets/diffview.nvim", cmd = { "DiffviewOpen", "DiffviewFileHistory" } },

  -- CMake: configure / build / run from inside Neovim.
  {
    "Civitasv/cmake-tools.nvim",
    ft = { "cmake", "c", "cpp" },
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {},
  },

  -- Treesitter parsers for the C/C++/CMake stack.
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, {
        "c", "cpp", "cmake", "make", "cuda", "gitcommit", "diff",
      })
    end,
  },

  -- clang-format for C/C++ via conform (bundled by NvChad).
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.c = { "clang-format" }
      opts.formatters_by_ft.cpp = { "clang-format" }
      opts.formatters_by_ft.cuda = { "clang-format" }
    end,
  },
}
