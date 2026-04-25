{ inputs, ... }:
{
  imports = [ (inputs.agenix-rekey.flakeModule or { }) ];
}
