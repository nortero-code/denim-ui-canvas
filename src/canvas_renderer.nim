import math
import sugar
import options
import canvas
import denim_ui

proc renderSegment(ctx: CanvasContext2d, segment: PathSegment): void =
  case segment.kind
  of MoveTo:
    ctx.moveTo(segment.to.x, segment.to.y)
  of LineTo:
    ctx.lineTo(segment.to.x, segment.to.y)
  of QuadraticCurveTo:
    let info = segment.quadraticInfo
    ctx.quadraticCurveTo(info.controlPoint.x, info.controlPoint.y, info.point.x, info.point.y)
  of BezierCurveTo:
    let info = segment.bezierInfo
    ctx.bezierCurveTo(info.controlPoint1.x, info.controlPoint1.y, info.controlPoint2.x, info.controlPoint2.y, info.point.x, info.point.y)
  of Close:
    ctx.closePath()

proc renderText(ctx: CanvasContext2d, colorInfo: Option[ColorInfo], textInfo: TextInfo): void =
  ctx.fillStyle = $colorInfo.map(x => x.fill.get(colRed)).get(colBrown)
  ctx.textAlign = textInfo.alignment
  ctx.textBaseline = textInfo.textBaseline
  ctx.font = $textInfo.fontSize & "px " & textInfo.font
  ctx.fillText(textInfo.text, 0.0, 0.0)

proc renderCircle(ctx: CanvasContext2d, radius: float): void =
  ctx.beginPath()
  ctx.arc(radius, radius, radius, 0, 2 * PI)

proc renderEllipse(ctx: CanvasContext2d, info: EllipseInfo): void =
  ctx.beginPath()
  let
    r = info.radius
  ctx.ellipse(0.0, 0.0, r.x, r.y, info.rotation, info.startAngle, info.endAngle)

proc setShadow(ctx: CanvasContext2d, shadow: Option[Shadow]): void =
  shadow.map(
    proc(shadow: Shadow): void =
      ctx.shadowBlur = shadow.size
      let (r,g,b) = shadow.color.extractRgb()
      ctx.setShadowColor(float(r),float(g),float(b), shadow.alpha)
      ctx.shadowOffsetX = shadow.offset.x
      ctx.shadowOffsetY = shadow.offset.y
  )

proc fillAndStroke(ctx: CanvasContext2d, colorInfo: Option[ColorInfo], strokeInfo: Option[StrokeInfo], shadow: Option[Shadow]): void =
  if strokeInfo.isSome():
    ctx.lineWidth = strokeInfo.get().width
  else:
    ctx.lineWidth = 0.0

  if colorInfo.isSome():
    let ci = colorInfo.get()
    if ci.fill.isSome():
      ctx.save()
      ctx.setShadow(shadow)
      ctx.fillStyle = $ci.fill.get()
      ctx.fill()
      ctx.restore()
    if ci.stroke.isSome() and strokeInfo.map(x => x.width).get(0.0) > 0.0:
      ctx.save()
      if ci.fill.isNone:
        # NOTE: We only apply shadow to the stroke if we haven't already applied it to.
        # This avoids shadows inside stroked shapes.
        ctx.setShadow(shadow)
      ctx.strokeStyle = $ci.stroke.get()
      ctx.stroke()
      ctx.restore()

proc renderPath*(ctx: CanvasContext2d, segments: seq[PathSegment]): void =
  ctx.beginPath()
  for segment in segments:
    renderSegment(ctx, segment)

proc renderPrimitive(ctx: CanvasContext2d, p: Primitive): void =
  case p.kind
  of PrimitiveKind.Container:
    discard
  of PrimitiveKind.Path:
    ctx.renderPath(p.segments)
    fillAndStroke(ctx, p.colorInfo, p.strokeInfo, p.shadow)
  of PrimitiveKind.Text:
    renderText(ctx, p.colorInfo, p.textInfo)
  of PrimitiveKind.Circle:
    let info = p.circleInfo
    renderCircle(ctx, info.radius)
    fillAndStroke(ctx, p.colorInfo, p.strokeInfo, p.shadow)
  of PrimitiveKind.Ellipse:
    let info = p.ellipseInfo
    renderEllipse(ctx, info)
    fillAndStroke(ctx, p.colorInfo, p.strokeInfo, p.shadow)
  of PrimitiveKind.Rectangle:
    let info = p.rectangleInfo
    ctx.beginPath()
    ctx.rect(info.bounds.pos.x, info.bounds.pos.y, info.bounds.size.x, info.bounds.size.y)
    fillAndStroke(ctx, p.colorInfo, p.strokeInfo, p.shadow)

proc render*(ctx: CanvasContext2d, primitive: Primitive): void =
  proc renderInner(primitive: Primitive): void =
    ctx.save()

    ctx.translate(primitive.bounds.x, primitive.bounds.y)
    for transform in  primitive.transform:
      case transform.kind:
        of Scaling:
          ctx.scale(
            transform.scale.x,
            transform.scale.y
          )
        of Translation:
          ctx.translate(transform.translation.x, transform.translation.y)
        of Rotation:
          ctx.rotate(transform.rotation)
    if primitive.clipToBounds:
      ctx.beginPath()
      let cb = primitive.bounds
      ctx.rect(0.0, 0.0, cb.size.x, cb.size.y)
      ctx.clip()
    ctx.renderPrimitive(primitive)
    for p in primitive.children:
      renderInner(p)
    ctx.restore()

  renderInner(primitive)
