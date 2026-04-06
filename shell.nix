{ pkgs ? import <nixpkgs> {} }:

with pkgs;

mkShell {
  buildInputs = [
    git
  ];
  KUBECONFIG = toString ./. + "/kubernetes/kubeconfig";
}
