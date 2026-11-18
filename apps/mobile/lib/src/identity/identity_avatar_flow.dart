import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../design_system/motion.dart';
import '../design_system/motion_routes.dart';
import '../design_system/telegram_theme.dart';
import '../localization/app_localizations.dart';
import '../posts/post_photo_picker.dart';

/// 头像流程的短暂失败提示：3 秒自动消失，可点「关闭」立即关闭。
/// 先清掉残留旧通知，避免排队叠加造成“不消失”的观感。
void notifyAvatarBlocked(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(hhText(context, message)),
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      // 本 SDK（3.50 预览版）中带 action 的 SnackBar persist 默认 true，
      // 定时器到点也不会消失；显式关闭以恢复自动消失。
      persist: false,
      action: SnackBarAction(
        label: hhText(context, '关闭'),
        onPressed: () => messenger.hideCurrentSnackBar(),
      ),
    ),
  );
}

/// 头像选择与圆形裁切流程：
/// 相册弹窗（权限拒绝时回退系统选择器）→ 圆形裁切编辑界面 → 已校验的 PNG。
/// 返回 null 表示用户取消。
Future<Uint8List?> pickIdentityAvatarImage(BuildContext context) async {
  var source = await _pickSource(context);
  while (source != null) {
    if (!context.mounted) return null;
    final result = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute<Uint8List>(
        builder: (_) => _AvatarCropEditor(bytes: source!.bytes),
      ),
    );
    if (result != null) return result;
    if (!context.mounted) return null;
    // 「重新选择」：回到相册（或系统选择器）再选一次。
    source = await _pickSource(context, preferSystem: source.fromSystem);
  }
  return null;
}

typedef _SourceResult = ({Uint8List bytes, bool fromSystem});

Future<_SourceResult?> _pickSource(
  BuildContext context, {
  bool preferSystem = false,
}) async {
  Uint8List? bytes;
  var fromSystem = preferSystem;
  if (!preferSystem) {
    var sheetShown = false;
    Object? picked;
    try {
      final permission = await PhotoManager.requestPermissionExtend();
      // 注意用 hasAccess 而非 isAuth：photo_manager 的 isAuth 只认完全授权
      // （authorized），Android 14「仅限所选照片」的部分授权（limited）会被
      // isAuth 误判为未授权——已授权却提示无权限的根因。部分授权下相册
      // 弹窗同样可用（只显示所选照片）。
      if (permission.hasAccess && context.mounted) {
        sheetShown = true;
        picked = await _openAlbumSheet(context);
      } else {
        // 未授权时 requestPermissionExtend 已自动弹系统授权框；仍被拒
        // （含永久拒绝）则回退系统选择器。
        debugPrint(
          'avatar album permission not granted: $permission, fallback',
        );
        fromSystem = true;
      }
    } on Object catch (error, stackTrace) {
      // 相册通道异常（常见于新增插件后未做完整重新构建，热重载不注册新通道）
      // → 回退系统选择器；debug 构建下打印原因便于区分“未实现”与“回退”。
      debugPrint('avatar album channel failed: $error\n$stackTrace');
      fromSystem = true;
    }
    if (sheetShown && picked == null) return null; // 弹窗被划走 = 取消整个流程。
    if (picked is AssetEntity) {
      Uint8List? origin;
      try {
        origin = await picked.originBytes;
      } on Object {
        origin = null;
      }
      if (origin != null) {
        bytes = origin;
        fromSystem = false;
      } else {
        // 部分授权（READ_MEDIA_VISUAL_USER_SELECTED）下 originBytes 可能为
        // null → 回退系统选择器，而不是静默取消。
        debugPrint('avatar asset originBytes unavailable, fallback to system');
        fromSystem = true;
      }
    } else if (picked == _useSystem) {
      fromSystem = true;
    }
  }
  if (fromSystem) {
    final files = await NativePostPhotoPicker().pick(1);
    if (files.isEmpty) return null;
    final file = files.single;
    // 头像流程不套用帖子级格式/像素校验（HEIC 等格式或大尺寸照片会被它
    // 以异常挡下，最终只显示笼统的“无法完成头像选择”）。这里仅保留 5MB
    // 读取上限；格式/动图等要求由裁切编辑界面在界面内准确提示。
    const avatarReadCap = 5 * 1024 * 1024;
    final builder = BytesBuilder(copy: false);
    var tooLarge = false;
    try {
      tooLarge = await file.length() > avatarReadCap;
      if (!tooLarge) {
        await for (final chunk in file.openRead()) {
          builder.add(chunk);
          if (builder.length > avatarReadCap) {
            tooLarge = true;
            break;
          }
        }
      }
    } finally {
      await file.release?.call();
    }
    if (tooLarge) {
      if (context.mounted) {
        notifyAvatarBlocked(context, '照片超过 5MB，请选择更小的照片。');
      }
      return null;
    }
    bytes = builder.takeBytes();
  }
  if (bytes == null) return null;
  return (bytes: bytes, fromSystem: fromSystem);
}

const _useSystem = 'use-system-picker';

Future<Object?> _openAlbumSheet(BuildContext context) {
  final sheetController = DraggableScrollableController();
  return showModalBottomSheet<Object?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: HhTelegramPalette.of(context).surface,
    // 手势可展开的相册弹窗：上滑跟手展开至全屏（进入全屏选图模式），
    // 下滑收起；网格随滚动驱动展开（DraggableScrollableSheet 标准用法）。
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .62,
      minChildSize: .3,
      maxChildSize: 1,
      snap: true,
      snapSizes: const [.62],
      controller: sheetController,
      builder: (context, scrollController) => _AlbumSheet(
        scrollController: scrollController,
        sheetController: sheetController,
      ),
    ),
  );
}

class _AlbumSheet extends StatefulWidget {
  const _AlbumSheet({
    required this.scrollController,
    required this.sheetController,
  });
  final ScrollController scrollController;
  final DraggableScrollableController sheetController;
  @override
  State<_AlbumSheet> createState() => _AlbumSheetState();
}

class _AlbumSheetState extends State<_AlbumSheet> {
  List<AssetEntity>? _assets;
  List<AssetPathEntity>? _albums;
  AssetPathEntity? _album;
  int? _albumCount;
  Object? _error;
  int _page = 0;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _menuOpen = false;
  static const _pageSize = 90;
  // 相册实体与分页查询共用创建时间降序，保证各页均按最新优先返回。
  static FilterOptionGroup _newestFirstFilter() => FilterOptionGroup(
    orders: const [OrderOption(type: OrderOptionType.createDate, asc: false)],
  );
  int _epoch = 0;
  @override
  void initState() {
    super.initState();
    // 先取相册列表（确定默认 isAll），再加载网格——保证初始与切换后
    // 走同一条实体分页查询，排序一致；列表失败时 _fetchPage 的空相册
    // 分支兜底。
    unawaited(_loadAlbums().then((_) => _load()));
  }

  // 设备相册分类（相机/截屏/收藏等），默认“全部照片”；切换后网格重载。
  Future<void> _loadAlbums() async {
    try {
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        hasAll: true,
        filterOption: _newestFirstFilter(),
      );
      if (!mounted) return;
      // “全部照片”固定置顶；其余保持系统返回顺序（Android 端本就在
      // 头部合成 isAll 相册，但名称硬编码为“Recent”，展示名在 UI 层
      // 覆盖为本地化的「全部照片」）。
      final sorted = [
        ...albums.where((album) => album.isAll),
        ...albums.where((album) => !album.isAll),
      ];
      AssetPathEntity? all;
      for (final album in sorted) {
        if (album.isAll) {
          all = album;
          break;
        }
      }
      all ??= sorted.isEmpty ? null : sorted.first;
      setState(() {
        _albums = sorted;
        if (_album == null && all != null) _album = all;
      });
      unawaited(_refreshAlbumCount());
    } catch (_) {
      // 相册列表加载失败不阻塞网格（继续按“全部照片”展示）。
    }
  }

  // 头部按钮展示的照片数；缓存避免随弹窗拖动的逐帧重建反复查询。
  Future<void> _refreshAlbumCount() async {
    final album = _album;
    if (album == null) return;
    try {
      final count = await album.assetCountAsync;
      if (mounted) setState(() => _albumCount = count);
    } catch (_) {
      // 数量查询失败仅省略显示。
    }
  }

  void _selectAlbum(AssetPathEntity album) {
    if (album.id == _album?.id) return;
    setState(() {
      _album = album;
      _albumCount = null;
    });
    unawaited(_refreshAlbumCount());
    _load();
  }

  Future<List<AssetEntity>> _fetchPage(int page) async {
    final album = _album;
    return album == null
        ? PhotoManager.getAssetListPaged(
            page: page,
            pageCount: _pageSize,
            type: RequestType.image,
            filterOption: _newestFirstFilter(),
          )
        : album.getAssetListPaged(page: page, size: _pageSize);
  }

  Future<void> _load() async {
    final epoch = ++_epoch;
    setState(() {
      _assets = null;
      _error = null;
      _page = 0;
      _hasMore = true;
      _loadingMore = false;
    });
    try {
      final items = await _fetchPage(0);
      if (!mounted || epoch != _epoch) return;
      setState(() {
        _assets = items;
        _hasMore = items.length >= _pageSize;
      });
    } catch (error) {
      if (!mounted || epoch != _epoch) return;
      setState(() => _error = error);
    }
  }

  // 分页懒加载：滚动接近底部时再取下一页。epoch 防切换相册后旧的
  // 在途请求把别的相册内容追加进来（顺序打乱的根因）；按 id 去重防
  // 分页边界抖动造成重复。
  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _assets == null || _error != null) {
      return;
    }
    final epoch = _epoch;
    setState(() => _loadingMore = true);
    try {
      final items = await _fetchPage(_page + 1);
      if (!mounted || epoch != _epoch) return;
      setState(() {
        _loadingMore = false;
        if (items.isEmpty) {
          _hasMore = false;
        } else {
          final known = _assets!.map((e) => e.id).toSet();
          final fresh = items.where((e) => !known.contains(e.id)).toList();
          _page++;
          _assets = [..._assets!, ...fresh];
          _hasMore = items.length >= _pageSize;
        }
      });
    } catch (_) {
      if (mounted && epoch == _epoch) {
        setState(() {
          _loadingMore = false;
          _hasMore = false;
        });
      }
    }
  }

  /// 下拉列表约束：宽度对齐按钮（整宽减去左右 16 内边距），高度随展开
  /// 进度自适应（半屏取较小上限、全屏取较大上限）。不跨树读取 RenderBox，
  /// 避免在 build 阶段访问已失效 element 触发断言。
  BoxConstraints _albumMenuConstraints() {
    final screen = MediaQuery.sizeOf(context);
    final width = screen.width - 32;
    // 按半屏高度保守估算按钮下方空间，避免访问 DraggableScrollableController。
    final maxHeight = (screen.height * .62 - 160).clamp(112.0, 376.0);
    return BoxConstraints(
      minWidth: width < 288.0 ? 288.0 : width,
      maxHeight: maxHeight,
    );
  }

  /// 扁平风相册选择按钮：整宽、底色块 + 细边框、图标 + 相册名 + 数量 +
  /// 下拉箭头；下拉面板同扁平（surface 底、1px 边框、零阴影、选中项带勾
  /// 与字重，不只靠颜色区分）。clipBehavior 使选中/悬停的高亮被裁剪到
  /// 面板圆角内，不再向外突出方角。isAll 相册展示名覆盖为「全部照片」
  /// （插件在 Android 上把该相册硬编码命名为“Recent”）。
  Widget _albumSelector(BuildContext context) {
    final p = HhTelegramPalette.of(context);
    final album = _album;
    String displayName(AssetPathEntity? item) =>
        item == null || item.isAll ? hhText(context, '全部照片') : item.name;
    return Material(
      color: p.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: p.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: PopupMenuButton<AssetPathEntity>(
        tooltip: hhText(context, '选择相册'),
        // 此参数约束按钮内部 InkWell；clipBehavior 仅作用于下拉菜单。
        borderRadius: BorderRadius.circular(12),
        initialValue: _album,
        onOpened: () => setState(() => _menuOpen = true),
        onCanceled: () => setState(() => _menuOpen = false),
        onSelected: (album) {
          setState(() => _menuOpen = false);
          _selectAlbum(album);
        },
        position: PopupMenuPosition.under,
        popUpAnimationStyle: HhMotionRoutes.popup(context),
        color: p.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: p.line),
        ),
        constraints: _albumMenuConstraints(),
        itemBuilder: (menuContext) => [
          for (final item in _albums ?? const <AssetPathEntity>[])
            PopupMenuItem(
              value: item,
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              // 占满整行：菜单项内容被外层 Align(centerStart) 定位，
              // 固定宽度会让数量停在宽度内而非菜单右缘。
              child: Row(
                children: [
                  Icon(
                    item.id == album?.id
                        ? Icons.check_rounded
                        : Icons.photo_library_outlined,
                    size: 18,
                    color: item.id == album?.id ? p.accent : p.secondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      displayName(item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: item.id == album?.id
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: p.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FutureBuilder<int>(
                    future: item.assetCountAsync,
                    builder: (context, snapshot) => Text(
                      snapshot.data?.toString() ?? '',
                      style: TextStyle(fontSize: 12, color: p.secondary),
                    ),
                  ),
                ],
              ),
            ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Icon(Icons.photo_library_outlined, size: 20, color: p.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  displayName(album),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: p.ink,
                  ),
                ),
              ),
              if (_albumCount != null) ...[
                Text(
                  '$_albumCount',
                  style: TextStyle(fontSize: 12, color: p.secondary),
                ),
                const SizedBox(width: 2),
              ],
              // 下拉列表打开时箭头反转向上，与身份切换等控件的动画节奏一致。
              AnimatedRotation(
                turns: _menuOpen ? .5 : 0,
                duration: HhMotion.duration(context, HhMotion.quick),
                child: Icon(
                  Icons.arrow_drop_down_rounded,
                  size: 22,
                  color: p.secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = HhTelegramPalette.of(context);
    final assets = _assets;
    return NotificationListener<ScrollNotification>(
      // 接近底部（约两屏）时预取下一页，实现全部照片的分页懒加载。
      onNotification: (notice) {
        if (notice.metrics.extentAfter < 600) {
          unawaited(_loadMore());
        }
        return false;
      },
      child: CustomScrollView(
        // 挂 DraggableScrollableSheet 的控制器：网格滚到顶后再上滑即展开
        // 弹窗，下滑即收起，全屏/半屏均跟手。
        controller: widget.scrollController,
        slivers: [
          // 仅头部随展开进度重建（全屏时避开状态栏），网格缩略图不受影响。
          SliverToBoxAdapter(
            // 头部内容固定为 child，展开进度只驱动外层 Padding，避免拖动
            // 逐帧重建相册按钮、箭头与文案，减少无谓重排。
            child: AnimatedBuilder(
              animation: widget.sheetController,
              builder: (context, _) {
                final expand = ((widget.sheetController.size - .62) / .38)
                    .clamp(0.0, 1.0);
                return Padding(
                  padding: EdgeInsets.only(
                    top: MediaQuery.paddingOf(context).top * expand,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: p.line,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                hhText(context, '设置头像'),
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: p.ink,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: hhText(context, '关闭'),
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: Text(
                          hhText(context, '上滑展开全屏，选择照片后进入圆形裁切。'),
                          style: TextStyle(fontSize: 13, color: p.secondary),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: _albumSelector(context),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      hhText(context, '无法读取相册，请重试。'),
                      style: TextStyle(color: p.error),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      children: [
                        TextButton(
                          onPressed: _load,
                          child: Text(hhText(context, '重新加载')),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, _useSystem),
                          child: Text(hhText(context, '改用系统选择器')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else if (assets == null)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
            )
          else if (assets.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  hhText(context, '相册里还没有照片'),
                  style: TextStyle(color: p.secondary),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                2,
                4,
                2,
                12 + MediaQuery.paddingOf(context).bottom,
              ),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final asset = assets[index];
                  return GestureDetector(
                    key: ValueKey('avatar-album-${asset.id}'),
                    onTap: () => Navigator.pop(context, asset),
                    child: _AlbumThumb(asset: asset),
                  );
                }, childCount: assets.length),
              ),
            ),
          if (_loadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AlbumThumb extends StatelessWidget {
  const _AlbumThumb({required this.asset});
  final AssetEntity asset;
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: asset.thumbnailDataWithSize(const ThumbnailSize(200, 200)),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          return ColoredBox(
            color: HhTelegramPalette.of(context).line,
            child: const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
      },
    );
  }
}

class _AvatarCropEditor extends StatefulWidget {
  const _AvatarCropEditor({required this.bytes});
  final Uint8List bytes;
  @override
  State<_AvatarCropEditor> createState() => _AvatarCropEditorState();
}

class _AvatarCropEditorState extends State<_AvatarCropEditor> {
  final _transform = TransformationController();
  ui.Image? _image;
  String? _error;
  bool _busy = false;
  double _stage = 0;

  static const _tooLarge = '照片超过 5MB，请选择更小的照片。';
  static const _animated = '头像不支持动图，请选择静态照片。';
  static const _undecodable = '这张照片暂时无法读取，请换一张重试。';

  @override
  void initState() {
    super.initState();
    _decode();
  }

  Future<void> _decode() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    final bytes = widget.bytes;
    if (bytes.length > 5 * 1024 * 1024) {
      if (mounted) setState(() => _busy = false);
      await _decodeForPreview();
      if (mounted) setState(() => _error = _tooLarge);
      return;
    }
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      try {
        if (codec.frameCount != 1) {
          await _decodeForPreview();
          if (mounted) setState(() => _error = _animated);
          return;
        }
        final frame = await codec.getNextFrame();
        if (mounted) setState(() => _image = frame.image);
      } finally {
        codec.dispose();
      }
    } catch (_) {
      if (mounted) setState(() => _error = _undecodable);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // 违规图片也保持预览，方便用户对照重新选择。
  Future<void> _decodeForPreview() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.bytes);
      try {
        final frame = await codec.getNextFrame();
        if (mounted) setState(() => _image = frame.image);
      } finally {
        codec.dispose();
      }
    } catch (_) {
      // 预览解码失败时只显示错误文案。
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    _transform.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final image = _image;
    if (image == null || _error != null || _busy) return;
    setState(() => _busy = true);
    try {
      final matrix = _transform.value;
      final scale = matrix.getMaxScaleOnAxis();
      // InteractiveViewer 的矩阵为缩放+平移：反推裁切圆心在子组件坐标系的位置。
      final center = ui.Offset(
        (_stage / 2 - matrix.storage[12]) / scale,
        (_stage / 2 - matrix.storage[13]) / scale,
      );
      final childRadius = (_stage * .34) / scale;
      // InteractiveViewer 内的图片按 contain 摆放，换算回像素坐标。
      final aspect = image.width / image.height;
      late double displayWidth, displayHeight, offsetX, offsetY;
      if (aspect >= 1) {
        displayWidth = _stage;
        displayHeight = _stage / aspect;
        offsetX = 0;
        offsetY = (_stage - displayHeight) / 2;
      } else {
        displayHeight = _stage;
        displayWidth = _stage * aspect;
        offsetX = (_stage - displayWidth) / 2;
        offsetY = 0;
      }
      final pixel = image.width / displayWidth;
      var radius = childRadius * pixel;
      radius = math.min(radius, math.min(image.width, image.height) / 2);
      var cx = ((center.dx - offsetX) * pixel).clamp(
        radius,
        image.width - radius,
      );
      var cy = ((center.dy - offsetY) * pixel).clamp(
        radius,
        image.height - radius,
      );
      final out = math.min(radius, 320).round();
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final paint = ui.Paint()..filterQuality = ui.FilterQuality.high;
      canvas.clipPath(
        ui.Path()..addOval(
          ui.Rect.fromCircle(
            center: ui.Offset(out.toDouble(), out.toDouble()),
            radius: out.toDouble(),
          ),
        ),
      );
      canvas.drawImageRect(
        image,
        ui.Rect.fromCircle(
          center: ui.Offset(cx.toDouble(), cy.toDouble()),
          radius: radius,
        ),
        ui.Rect.fromCircle(
          center: ui.Offset(out.toDouble(), out.toDouble()),
          radius: out.toDouble(),
        ),
        paint,
      );
      final picture = recorder.endRecording();
      try {
        final output = await picture.toImage(out * 2, out * 2);
        try {
          final data = await output.toByteData(format: ui.ImageByteFormat.png);
          if (data == null) {
            throw const FormatException('Avatar encoding failed');
          }
          if (mounted) {
            Navigator.pop(
              context,
              data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
            );
          }
        } finally {
          output.dispose();
        }
      } finally {
        picture.dispose();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = _undecodable);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = HhTelegramPalette.of(context);
    final image = _image;
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.surface,
        foregroundColor: p.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          hhText(context, '设置头像'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: p.ink,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final stage = math.min(
                      constraints.biggest.width - 40,
                      constraints.biggest.height - 40,
                    );
                    _stage = stage;
                    return SizedBox(
                      width: stage,
                      height: stage,
                      child: Stack(
                        children: [
                          if (image != null)
                            InteractiveViewer(
                              transformationController: _transform,
                              maxScale: 4,
                              minScale: 1,
                              boundaryMargin: const EdgeInsets.all(1e6),
                              child: SizedBox(
                                width: stage,
                                height: stage,
                                child: RawImage(
                                  image: image,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          IgnorePointer(
                            child: CustomPaint(
                              painter: _CropRingPainter(
                                color: p.background,
                                ring: p.accent,
                              ),
                              size: Size.square(stage),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                hhText(context, '拖动调整位置 · 双指缩放'),
                style: TextStyle(fontSize: 12, color: p.secondary),
              ),
            ),
            if (_error case final error?)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  hhText(context, error),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: p.error),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(hhText(context, '重新选择')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('avatar-crop-confirm'),
                      onPressed: _error != null || _busy
                          ? null
                          : () => _confirm(),
                      child: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(hhText(context, '确认')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CropRingPainter extends CustomPainter {
  const _CropRingPainter({required this.color, required this.ring});
  final Color color, ring;
  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width * .34;
    final rect = Offset.zero & size;
    // 半透明遮罩盖住圆外区域，圆内保持透亮。
    canvas.saveLayer(rect.inflate(1), Paint());
    canvas.drawRect(rect, Paint()..color = color.withValues(alpha: .72));
    canvas.drawCircle(
      rect.center,
      radius,
      Paint()
        ..blendMode = BlendMode.clear
        ..color = const Color(0x00000000),
    );
    canvas.restore();
    canvas.drawCircle(
      rect.center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = ring,
    );
  }

  @override
  bool shouldRepaint(_CropRingPainter old) =>
      old.color != color || old.ring != ring;
}
