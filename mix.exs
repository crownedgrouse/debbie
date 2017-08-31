defmodule Edgar.Mixfile do
  use Mix.Project

  def project do
    [app: :debbie,
     version: "1.0.4",
     elixir: "~> 1.2",
     description: description(),
     package: package(),
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [applications: []]
  end

  defp deps() do
    [
      {:edgar,  "~> 1.0"},
      {:swab,   "~> 1.0"},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp description() do
    ".DEB Built In Erlang"
  end

  defp package() do
    [
      # These are the default files included in the package
      files: ["src", "doc", "priv", "mix.exs", "README.md", "LICENSE", "Makefile", "erlang.mk", "lock.mk", "rebar.config"],
      maintainers: ["Eric Pailleau"],
      licenses: ["ISC"],
      links: %{"GitHub" => "https://github.com/crownedgrouse/debbie"}
    ]
  end
end
