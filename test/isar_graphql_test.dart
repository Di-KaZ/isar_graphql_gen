import 'package:isar_graphql/isar_graphql.dart';
import 'package:isar_graphql/src/isar_collection_builder.dart';
import 'package:isar_graphql/src/types_and_fragment_visitor.dart';
import 'package:test/test.dart';
import "package:gql/language.dart" as lang;

void main() {
  group('fragment parsing', () {
    setUp(() {
      // Additional setup goes here.
    });

    test('basic', () {
      final doc = lang.parseString("""
        type Test {
          id: String
          a_number: Int
        }

        fragment TestFragment on Test {
          a_number
          id
        }
        """);
      final typesAndFragDefinition = TypeAndFragmentVisitor();
      doc.accept(typesAndFragDefinition);

      expect(typesAndFragDefinition.types.length, 1);
      expect(typesAndFragDefinition.fragments.length, 1);

      final AbstractIsarBuilder collectionbuilder = IsarCollectionBuilder(
        typesAndFragDefinition.types,
        typesAndFragDefinition.fragments.values.first,
      );

      final res = collectionbuilder.build();

      expect(
        res,
        """@collection
class IsarCollection\$TestFragment {
  Int? a_number;

  String? id;
}
""",
      );
    });

    test('nested', () {
      final doc = lang.parseString("""
        type Test {
          id: String
          a_number: Int
          other: OtherTest!
        }

        type OtherTest {
          id: String
          incredible: Bool!
        }

        fragment TestFragment on Test {
          a_number
          id
          other {
            incredible
          }
        }
        """);
      final typesAndFragDefinition = TypeAndFragmentVisitor();
      doc.accept(typesAndFragDefinition);

      expect(typesAndFragDefinition.types.length, 2);
      expect(typesAndFragDefinition.fragments.length, 1);

      final AbstractIsarBuilder collectionbuilder = IsarCollectionBuilder(
        typesAndFragDefinition.types,
        typesAndFragDefinition.fragments.values.first,
      );

      final res = collectionbuilder.build();

      expect(
        res,
        """@collection
class Isar\$TestFragment {
  Int? a_number;

  String? id;
}
""",
      );
    });
  });
}
