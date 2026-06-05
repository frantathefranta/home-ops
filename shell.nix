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
    yq
    vals
  ];
  KUBECONFIG = toString ./. + "/kubernetes/kubeconfig";
}
