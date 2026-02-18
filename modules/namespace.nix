{ inputs, ... }:
{
  imports = [ (inputs.den.namespace "my" false) ];
}
