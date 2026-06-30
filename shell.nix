{ pkgs ? import <nixpkgs-unstable> {} }:

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
    talhelper
    cilium-cli
  ];
  KUBECONFIG = toString ./. + "/kubernetes/kubeconfig";
  TALOSCONFIG = toString ./. + "/talos/clusterconfig/talosconfig";
}
