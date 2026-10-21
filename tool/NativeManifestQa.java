// Local-only regression fixture using the same manifest-merger version as AGP.
// Does not build/install an APK or modify source manifests.
import com.android.manifmerger.ManifestMerger2;
import com.android.manifmerger.ManifestSystemProperty;
import com.android.manifmerger.MergingReport;
import com.android.utils.ILogger;
import java.nio.file.Files;
import java.nio.file.Path;
import javax.xml.XMLConstants;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.stream.StreamResult;
import org.w3c.dom.Element;

public final class NativeManifestQa {
    private static final String ANDROID = "http://schemas.android.com/apk/res/android";
    private static final ILogger LOG = new ILogger() {
        public void error(Throwable t, String message, Object... args) {
            System.err.println(String.format(message, args));
            if (t != null) t.printStackTrace();
        }
        public void warning(String message, Object... args) { System.err.println(String.format(message, args)); }
        public void info(String message, Object... args) { }
        public void verbose(String message, Object... args) { }
    };
    private static DocumentBuilderFactory xmlFactory() throws Exception {
        var factory = DocumentBuilderFactory.newInstance();
        factory.setNamespaceAware(true);
        factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
        factory.setAttribute(XMLConstants.ACCESS_EXTERNAL_DTD, "");
        factory.setAttribute(XMLConstants.ACCESS_EXTERNAL_SCHEMA, "");
        return factory;
    }
    private static void merge(Path app, Path unity, Path output) throws Exception {
        var report = ManifestMerger2.newMerger(app.toFile(), LOG, ManifestMerger2.MergeType.APPLICATION)
            .setNamespace("com.halabessa.game")
            .setOverride(ManifestSystemProperty.valueOf("PACKAGE"), "com.halabessa.game")
            .setOverride(ManifestSystemProperty.valueOf("MIN_SDK_VERSION"), "23")
            .setOverride(ManifestSystemProperty.valueOf("TARGET_SDK_VERSION"), "36")
            .setPlaceHolderValue("applicationName", "android.app.Application")
            .addLibraryManifest(unity.toFile()).merge();
        report.log(LOG);
        if (report.getResult().isError()) throw new IllegalStateException(report.getReportString());
        Files.writeString(output, report.getMergedDocument(MergingReport.MergedManifestKind.MERGED));
    }
    public static void main(String[] args) throws Exception {
        if (args.length != 1) throw new IllegalArgumentException("Pass the checkout root.");
        var root = Path.of(args[0]).toRealPath();
        var app = root.resolve("android/app/src/main/AndroidManifest.xml");
        var unity = root.resolve("androidBuild/unityExport/unityLibrary/src/main/AndroidManifest.xml");
        var output = root.resolve("build/native-manifest-qa").normalize();
        if (!output.startsWith(root.resolve("build"))) throw new IllegalStateException("Invalid QA output.");
        Files.createDirectories(output);
        // AGP processes the library's namespace before app merging. Its raw
        // exported source intentionally has no package attribute.
        var library = ManifestMerger2.newMerger(unity.toFile(), LOG, ManifestMerger2.MergeType.LIBRARY)
            .setNamespace("com.unity3d.player")
            .setOverride(ManifestSystemProperty.valueOf("PACKAGE"), "com.unity3d.player")
            .setOverride(ManifestSystemProperty.valueOf("MIN_SDK_VERSION"), "23")
            .setOverride(ManifestSystemProperty.valueOf("TARGET_SDK_VERSION"), "36")
            .merge();
        if (library.getResult().isError()) throw new IllegalStateException(library.getReportString());
        var processedUnity = output.resolve("unity-library-processed.xml");
        Files.writeString(processedUnity, library.getMergedDocument(MergingReport.MergedManifestKind.MERGED));
        merge(app, processedUnity, output.resolve("merged-fixed.xml"));

        // Negative control: reproduce the old duplicate launcher by removing only
        // our Flutter-app override, never by modifying the real source manifest.
        var old = xmlFactory().newDocumentBuilder().parse(app.toFile());
        var activities = old.getElementsByTagName("activity");
        for (int i = activities.getLength() - 1; i >= 0; i--) {
            var element = (Element) activities.item(i);
            if (element.getAttributeNS(ANDROID, "name").equals("com.unity3d.player.UnityPlayerActivity")) {
                element.getParentNode().removeChild(element);
            }
        }
        var transformer = TransformerFactory.newInstance();
        transformer.setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true);
        transformer.setAttribute(XMLConstants.ACCESS_EXTERNAL_DTD, "");
        transformer.setAttribute(XMLConstants.ACCESS_EXTERNAL_STYLESHEET, "");
        var baseline = output.resolve("app-without-launcher-fix.xml");
        transformer.newTransformer().transform(new DOMSource(old), new StreamResult(baseline.toFile()));
        merge(baseline, processedUnity, output.resolve("merged-baseline.xml"));
        System.out.println("Merged current app + included Unity library; negative control generated. APK not built.");
    }
}
