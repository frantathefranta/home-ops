{ pkgs ? import <nixpkgs> {} }:

with pkgs;

mkShell {
  buildInputs = [
    git
    yaml-language-server
    kubernetes-helm
    helm-ls
  ];
  KUBECONFIG = toString ./. + "/kubernetes/kubeconfig";
}
