{ inputs, ... }:
{
  imports = [ (inputs.den.namespace "oscarmarshall" false) ];
}
