{ pkgs ? import <nixpkgs> {} }:

with pkgs;

mkShell {
  buildInputs = [
    git
    yaml-language-server
    kubernetes-helm
    helm-ls
    just
    gum
    talosctl
  ];
  KUBECONFIG = toString ./. + "/kubernetes/kubeconfig";
}
