import 'package:dicebear_core/dicebear_core.dart';
import 'package:dicebear_styles/thumbs.dart';

/// The fixed set of predefined avatars offered during onboarding and from
/// the Profile screen. Each entry is a seed string for DiceBear's "Thumbs"
/// style - an abstract thumbs-up icon with simple eyes/mouth, no human
/// figure, body, or clothing at all, so there's no modesty or
/// gender-depiction question to weigh. Hand-picked from a preview batch
/// rather than left random.
const List<String> avatarSeeds = [
  'wird-thumb-0',
  'wird-thumb-2',
  'wird-thumb-3',
  'wird-thumb-5',
  'wird-thumb-7',
  'wird-thumb-12',
  'wird-thumb-18',
  'wird-thumb-19',
  'wird-thumb-22',
];

/// SVG markup for a predefined avatar seed - rendered fully locally, no
/// network call. This is core app identity, not a Friends-only concept -
/// see ProfileAvatar, the widget that actually displays it.
String avatarSvgFor(String seed) => Avatar(Style.parse(thumbs), {'seed': seed}).svg;
