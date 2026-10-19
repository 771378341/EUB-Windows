import 'package:flutter/material.dart';

import '../common/app_theme.dart';
import '../components/player/danmaku/danmaku_api.dart';

class DanmakuApiSettingsPage extends StatefulWidget {
  const DanmakuApiSettingsPage({super.key});
  @override
  State<DanmakuApiSettingsPage> createState() => _DanmakuApiSettingsPageState();
}

class _DanmakuApiSettingsPageState extends State<DanmakuApiSettingsPage> {
  final _url = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final url = await DanmakuApi.loadBaseUrl();
    if (!mounted) return;
    setState(() {
      _url.text = url;
      _loading = false;
    });
  }

  Future<void> _save({bool reset = false}) async {
    if (_saving || _loading) return;
    if (!reset && !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await DanmakuApi.saveBaseUrl(
        reset ? DanmakuApi.defaultBaseUrl : _url.text,
      );
      if (!mounted) return;
      if (reset) _url.text = DanmakuApi.defaultBaseUrl;
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(reset ? '已恢复默认弹幕接口' : '弹幕接口已保存')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('保存失败，请检查地址后重试')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('弹幕接口')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '接口基础地址',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _url,
                        enabled: !_saving,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(
                          hintText: 'https://example.com/danmaku',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          try {
                            DanmakuApi.normalizeBaseUrl(value ?? '');
                            return null;
                          } on FormatException catch (e) {
                            return e.message;
                          }
                        },
                        onFieldSubmitted: (_) => _save(),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '支持弹弹play兼容接口。填写基础地址，不要附加 /api/v2/match 等请求路径。保存后，下次打开视频时生效。',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton(
                            onPressed: _saving ? null : () => _save(),
                            child: Text(_saving ? '保存中…' : '保存'),
                          ),
                          OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => _save(reset: true),
                            child: const Text('恢复默认'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
  );
}
