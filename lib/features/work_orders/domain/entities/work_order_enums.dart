enum WoType {
  cm('CM'),
  pm('PM'),
  ins('INS'),
  inst('INST'),
  dec('DEC'),
  upg('UPG');

  const WoType(this.value);
  final String value;

  static WoType fromValue(String v) =>
      WoType.values.firstWhere((e) => e.value == v);
}

enum WoPriority {
  p1('P1'),
  p2('P2'),
  p3('P3'),
  p4('P4');

  const WoPriority(this.value);
  final String value;

  static WoPriority fromValue(String v) =>
      WoPriority.values.firstWhere((e) => e.value == v);
}

enum WoStatus {
  created('created'),
  assigned('assigned'),
  accepted('accepted'),
  enRoute('en_route'),
  onSite('on_site'),
  inProgress('in_progress'),
  paused('paused'),
  awaitingParts('awaiting_parts'),
  completed('completed'),
  reviewed('reviewed'),
  closed('closed'),
  cancelled('cancelled'),
  rejected('rejected');

  const WoStatus(this.value);
  final String value;

  static WoStatus fromValue(String v) =>
      WoStatus.values.firstWhere((e) => e.value == v);
}

enum WoOrigin {
  dispatcher('dispatcher'),
  technician('technician');

  const WoOrigin(this.value);
  final String value;

  static WoOrigin fromValue(String v) =>
      WoOrigin.values.firstWhere((e) => e.value == v);
}

enum WoOutcome {
  resolved('resolved'),
  partsOrdered('parts_ordered'),
  escalated('escalated'),
  beyondEconomicRepair('beyond_economic_repair'),
  cancelled('cancelled');

  const WoOutcome(this.value);
  final String value;

  static WoOutcome fromValue(String v) =>
      WoOutcome.values.firstWhere((e) => e.value == v);
}

enum BillingFlag {
  warranty('warranty'),
  contract('contract'),
  chargeable('chargeable'),
  thirdPartyRecoverable('third_party_recoverable');

  const BillingFlag(this.value);
  final String value;

  static BillingFlag fromValue(String v) =>
      BillingFlag.values.firstWhere((e) => e.value == v);
}

enum PhotoStage {
  before('before'),
  during('during'),
  after('after');

  const PhotoStage(this.value);
  final String value;

  static PhotoStage fromValue(String v) =>
      PhotoStage.values.firstWhere((e) => e.value == v);
}

enum SignerRole {
  technician('technician'),
  facility('facility');

  const SignerRole(this.value);
  final String value;

  static SignerRole fromValue(String v) =>
      SignerRole.values.firstWhere((e) => e.value == v);
}
