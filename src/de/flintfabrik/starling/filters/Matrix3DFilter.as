package de.flintfabrik.starling.filters
{
	import com.adobe.utils.PerspectiveMatrix3D;
	import flash.display3D.Context3D;
	import flash.display3D.Context3DProgramType;
	import flash.display3D.Context3DVertexBufferFormat;
	import flash.display3D.IndexBuffer3D;
	import flash.display3D.Program3D;
	import flash.display3D.VertexBuffer3D;
	import flash.errors.IllegalOperationError;
	import flash.geom.Matrix;
	import flash.geom.Matrix3D;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.geom.Vector3D;
	import flash.system.Capabilities;
	import flash.utils.getQualifiedClassName;
	import starling.core.RenderSupport;
	import starling.core.Starling;
	import starling.core.starling_internal;
	import starling.display.BlendMode;
	import starling.display.DisplayObject;
	import starling.display.Image;
	import starling.display.QuadBatch;
	import starling.display.Stage;
	import starling.errors.AbstractClassError;
	import starling.errors.MissingContextError;
	import starling.events.Event;
	import starling.filters.FragmentFilter;
	import starling.filters.FragmentFilterMode;
	import starling.textures.Texture;
	import starling.utils.getNextPowerOfTwo;
	import starling.utils.MatrixUtil;
	import starling.utils.RectangleUtil;
	import starling.utils.VertexData;
    
    /** The Matrix3DFilter class is a filter to create a 2.5D effect.
	 *  This gives you the ability to set properties of a perspective transformation; translate and rotate
	 *  DisplayObjects around X/Y/Z-axes. On the other hand this will definitely cause problems with touches
	 *  and most likely with all other sort of things. So it would be wise not to use it. That's up to you.
	 *  
	 *  @see starling.filters.FragmentFilter
	 *
	 *  @see http://www.flintfabrik.de
	 *  @author Michael Trenkler
     */
    public class Matrix3DFilter extends FragmentFilter
    {
		private var mAspect:Number = 1;
		private var mMatrix:Matrix3D = new Matrix3D();
        private var mProjectionTransform:PerspectiveMatrix3D = new PerspectiveMatrix3D();
		private var mShaderProgram:Program3D; 
		
		/**
		 * The camera's field of view in degrees.
		 * @default 45
		 */
		public var fov:Number = 45;
		/**
		 * X translation in 3D space.
		 * @default 0
		 */
		public var positionX:Number = 0;
        /**
		 * Y translation in 3D space.
		 * @default 0
		 */
		public var positionY:Number = 0;
        /**
		 * Z translation in 3D space.
		 * @default 500
		 */
		public var positionZ:Number = 500;
		/**
		 * Rotation around the X-axis in 3D space.
		 * @default 0
		 */
        public var rotationX:Number = 0;
		/**
		 * Rotation around the Y-axis in 3D space.
		 * @default 0
		 */
		public var rotationY:Number = 0;
		/**
		 * Rotation around the Z-axis in 3D space.
		 * @default 0
		 */
		public var rotationZ:Number = 0;
		/**
		 * The distance of the frustum's far pane to the camera.
		 */
		public var zFar:Number = 1000;
		/**
		 * The distance of the frustum's near pane to the camera.
		 */
		public var zNear:Number = 0;
		
        /** Creates a new Matrix3DFilter. 
         *  @param innerRadius: Values greater 0 result in a "donut"
		 *  @param outerRadius: the overall radius of the effect
		 * 
         */
        public function Matrix3DFilter(resolution:Number=1)
        {
			// creating the super class and immediately afterwards dispose it, since almost a complete copy of FragmentFilter is included in this document.
			super(1, 0.00001);
			super.dispose();
			FragmentFilterCOPY(1, resolution);
        }
		
        override protected function activate(pass:int, context:Context3D, texture:Texture):void
        {
			context.setProgram(mShaderProgram);
			context.setScissorRectangle(null); // otherwise the object would get clipped to the original bounds
        }
		
		/** @private */
        override protected function createPrograms():void
        {
			if (mShaderProgram) mShaderProgram.dispose();
			mShaderProgram = assembleAgal(null, STD_VERTEX_SHADER);
        }
		
		/** @inheritDoc */
        override public function dispose():void
        {
            if (mShaderProgram) mShaderProgram.dispose();
            super.dispose();
			disposeFFCOPY();
        }
		
		/**
		 * The custom render function which pre-/appends the custom properties and perspective matrix.
		 * @param	object
		 * @param	support
		 * @param	parentAlpha
		 * @param	intoCache
		 * @return
		 */
		private function renderPasses(object:DisplayObject, support:RenderSupport, 
                                      parentAlpha:Number, intoCache:Boolean=false):QuadBatch
        {
			mProjectionTransform.perspectiveFieldOfViewLH(fov*Math.PI/180, mAspect, zNear, zFar);
			
            var passTexture:Texture;
            var cacheTexture:Texture = null;
            var stage:Stage = object.stage;
            var context:Context3D = Starling.context;
            var scale:Number = Starling.current.contentScaleFactor;
            
            if (stage   == null) throw new Error("Filtered object must be on the stage.");
            if (context == null) throw new MissingContextError();
            
            // the bounds of the object in stage coordinates 
            calculateBounds(object, stage, mResolution * scale, !intoCache, sBounds, sBoundsPot);
            
            if (sBounds.isEmpty())
            {
                disposePassTextures();
                return intoCache ? new QuadBatch() : null; 
            }
            
            updateBuffers(context, sBoundsPot);
            updatePassTextures(sBoundsPot.width, sBoundsPot.height, mResolution * scale);
            
            support.finishQuadBatch();
            support.raiseDrawCount(mNumPasses);
            support.pushMatrix();
            
            // save original projection matrix and render target
            mProjMatrix.copyFrom(support.projectionMatrix); 
            var previousRenderTarget:Texture = support.renderTarget;
            
            if (previousRenderTarget)
                throw new IllegalOperationError(
                    "It's currently not possible to stack filters! " +
                    "This limitation will be removed in a future Stage3D version.");
            
            if (intoCache) 
                cacheTexture = Texture.empty(sBoundsPot.width, sBoundsPot.height, PMA, false, true, 
                                             mResolution * scale);
            
            // draw the original object into a texture
            support.renderTarget = mPassTextures[0];
            support.clear();
            support.blendMode = BlendMode.NORMAL;
            support.setOrthographicProjection(sBounds.x, sBounds.y, sBoundsPot.width, sBoundsPot.height);
            object.render(support, parentAlpha);
            support.finishQuadBatch();
            
            // prepare drawing of actual filter passes
            RenderSupport.setBlendFactors(PMA);
            support.loadIdentity();  // now we'll draw in stage coordinates!
            support.pushClipRect(sBounds);
            
            context.setVertexBufferAt(mVertexPosAtID, mVertexBuffer, VertexData.POSITION_OFFSET, 
                                      Context3DVertexBufferFormat.FLOAT_2);
            context.setVertexBufferAt(mTexCoordsAtID, mVertexBuffer, VertexData.TEXCOORD_OFFSET,
                                      Context3DVertexBufferFormat.FLOAT_2);
            
            // draw all passes
            for (var i:int=0; i<mNumPasses; ++i)
            {
                if (i < mNumPasses - 1) // intermediate pass  
                {
                    // draw into pass texture
                    support.renderTarget = getPassTexture(i+1);
                    support.clear();
                }
                else // final pass
                {
                    if (intoCache)
                    {
                        // draw into cache texture
                        support.renderTarget = cacheTexture;
                        support.clear();
                    }
                    else
                    {
                        // draw into back buffer, at original (stage) coordinates
                        support.projectionMatrix = mProjMatrix;
                        support.renderTarget = previousRenderTarget;
                        support.translateMatrix(mOffsetX, mOffsetY);
                        support.blendMode = object.blendMode;
                        support.applyBlendMode(PMA);
                    }
                }
                
                passTexture = getPassTexture(i);
				
				/* here is where the magic happens */
				var m:Matrix3D = support.mvpMatrix3D.clone();
				var pivot:Point = object.localToGlobal(new Point(object.pivotX, object.pivotY));
				m.prependTranslation(0,0,positionX);
				m.prependTranslation(0,0,positionY);
				m.prependTranslation(0,0,positionZ);
				m.appendScale(200,200,1);
				m.prependRotation(rotationX, Vector3D.X_AXIS, new Vector3D(pivot.x, pivot.y, 0));
				m.prependRotation(rotationY, Vector3D.Y_AXIS, new Vector3D(pivot.x, pivot.y, 0));
				m.prependRotation(rotationZ, Vector3D.Z_AXIS, new Vector3D(pivot.x, pivot.y, 0));
				m.append(mProjectionTransform);
				/* end */
				
                context.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, mMvpConstantID, 
                                                      m, true);
                context.setTextureAt(mBaseTextureID, passTexture.base);
                
                activate(i, context, passTexture);
                context.drawTriangles(mIndexBuffer, 0, 2);
                deactivate(i, context, passTexture);
            }
            
            // reset shader attributes
            context.setVertexBufferAt(mVertexPosAtID, null);
            context.setVertexBufferAt(mTexCoordsAtID, null);
            context.setTextureAt(mBaseTextureID, null);
            
            support.popMatrix();
            support.popClipRect();
            
            if (intoCache)
            {
                // restore support settings
                support.renderTarget = previousRenderTarget;
                support.projectionMatrix.copyFrom(mProjMatrix);
                
                // Create an image containing the cache. To have a display object that contains
                // the filter output in object coordinates, we wrap it in a QuadBatch: that way,
                // we can modify it with a transformation matrix.
                
                var quadBatch:QuadBatch = new QuadBatch();
                var image:Image = new Image(cacheTexture);
                
                stage.getTransformationMatrix(object, sTransformationMatrix);
                MatrixUtil.prependTranslation(sTransformationMatrix, 
                                              sBounds.x + mOffsetX, sBounds.y + mOffsetY);
                quadBatch.addImage(image, 1.0, sTransformationMatrix);
				
                return quadBatch;
            }
            else return null;
        }
		
		
		
		
		
		
		
		
		
		///////////////////////////////////////////////////// FRAGMENT FILTER COPY //////////////////////////////////////////////////////
		// unfortunately most of the variables and functions of the super class are private, so I had to create almost a complete copy //
		/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		
		
		
		
		
		
		 /** The minimum size of a filter texture. */
        private const MIN_TEXTURE_SIZE:int = 64;
        
        private var mVertexPosAtID:int = 0;
        private var mTexCoordsAtID:int = 1;
        private var mBaseTextureID:int = 0;
        private var mMvpConstantID:int = 0;
        
        private var mNumPasses:int;
        private var mPassTextures:Vector.<Texture>;

        private var mMode:String;
        private var mResolution:Number;
        private var mMarginX:Number;
        private var mMarginY:Number;
        private var mOffsetX:Number;
        private var mOffsetY:Number;
        
        private var mVertexData:VertexData;
        private var mVertexBuffer:VertexBuffer3D;
        private var mIndexData:Vector.<uint>;
        private var mIndexBuffer:IndexBuffer3D;
        
        private var mCacheRequested:Boolean;
        private var mCache:QuadBatch;
        
        /** helper objects. */
        private var mProjMatrix:Matrix = new Matrix();
        private static var sBounds:Rectangle  = new Rectangle();
        private static var sBoundsPot:Rectangle = new Rectangle();
        private static var sStageBounds:Rectangle = new Rectangle();
        private static var sTransformationMatrix:Matrix = new Matrix();
        
        /** Creates a new Fragment filter with the specified number of passes and resolution.
         *  This constructor may only be called by the constructor of a subclass. */
        public function FragmentFilterCOPY(numPasses:int=1, resolution:Number=1.0):void
        {
            
            if (numPasses < 1) throw new ArgumentError("At least one pass is required.");
            
            mNumPasses = numPasses;
            mMarginX = mMarginY = 0.0;
            mOffsetX = mOffsetY = 0;
            mResolution = resolution;
            mMode = FragmentFilterMode.REPLACE;
            
            mVertexData = new VertexData(4);
            mVertexData.setTexCoords(0, 0, 0);
            mVertexData.setTexCoords(1, 1, 0);
            mVertexData.setTexCoords(2, 0, 1);
            mVertexData.setTexCoords(3, 1, 1);
            
            mIndexData = new <uint>[0, 1, 2, 1, 3, 2];
            mIndexData.fixed = true;
            
            createPrograms();
            
            // Handle lost context. By using the conventional event, we can make it weak; this  
            // avoids memory leaks when people forget to call "dispose" on the filter.
            Starling.current.stage3D.addEventListener(Event.CONTEXT3D_CREATE, 
                onContextCreated, false, 0, true);
        }
        
        /** Disposes the filter (programs, buffers, textures). */
        public function disposeFFCOPY():void
        {
            Starling.current.stage3D.removeEventListener(Event.CONTEXT3D_CREATE, onContextCreated);
            if (mVertexBuffer) mVertexBuffer.dispose();
            if (mIndexBuffer)  mIndexBuffer.dispose();
            disposePassTextures();
            disposeCache();
        }
        
        private function onContextCreated(event:Object):void
        {
            mVertexBuffer = null;
            mIndexBuffer  = null;
            mPassTextures = null;
            
            createPrograms();
        }
        
        // helper methods
        
        private function updateBuffers(context:Context3D, bounds:Rectangle):void
        {
            mVertexData.setPosition(0, bounds.x, bounds.y);
            mVertexData.setPosition(1, bounds.right, bounds.y);
            mVertexData.setPosition(2, bounds.x, bounds.bottom);
            mVertexData.setPosition(3, bounds.right, bounds.bottom);
            
            if (mVertexBuffer == null)
            {
                mVertexBuffer = context.createVertexBuffer(4, VertexData.ELEMENTS_PER_VERTEX);
                mIndexBuffer  = context.createIndexBuffer(6);
                mIndexBuffer.uploadFromVector(mIndexData, 0, 6);
            }
            
            mVertexBuffer.uploadFromVector(mVertexData.rawData, 0, 4);
        }
        
        private function updatePassTextures(width:int, height:int, scale:Number):void
        {
            var numPassTextures:int = mNumPasses > 1 ? 2 : 1;
            var needsUpdate:Boolean = mPassTextures == null || 
                mPassTextures.length != numPassTextures ||
                mPassTextures[0].width != width || mPassTextures[0].height != height;  
            
            if (needsUpdate)
            {
                if (mPassTextures)
                {
                    for each (var texture:Texture in mPassTextures) 
                        texture.dispose();
                    
                    mPassTextures.length = numPassTextures;
                }
                else
                {
                    mPassTextures = new Vector.<Texture>(numPassTextures);
                }
                
                for (var i:int=0; i<numPassTextures; ++i)
                    mPassTextures[i] = Texture.empty(width, height, PMA, false, true, scale);
            }
        }
        
        private function getPassTexture(pass:int):Texture
        {
            return mPassTextures[pass % 2];
        }
        
        /** Calculates the bounds of the filter in stage coordinates. The method calculates two
         *  rectangles: one with the exact filter bounds, the other with an extended rectangle that
         *  will yield to a POT size when multiplied with the current scale factor / resolution.
         */
        private function calculateBounds(object:DisplayObject, stage:Stage, scale:Number, 
                                         intersectWithStage:Boolean, 
                                         resultRect:Rectangle,
                                         resultPotRect:Rectangle):void
        {
            var marginX:Number, marginY:Number;
            
            if (object == stage || object == Starling.current.root)
            {
                // optimize for full-screen effects
                marginX = marginY = 0;
                resultRect.setTo(0, 0, stage.stageWidth, stage.stageHeight);
            }
            else
            {
                marginX = mMarginX;
                marginY = mMarginY;
                object.getBounds(stage, resultRect);
            }
            
            if (intersectWithStage)
            {
                sStageBounds.setTo(0, 0, stage.stageWidth, stage.stageHeight);
                RectangleUtil.intersect(resultRect, sStageBounds, resultRect);
            }
            
            if (!resultRect.isEmpty())
            {    
                // the bounds are a rectangle around the object, in stage coordinates,
                // and with an optional margin. 
                resultRect.inflate(marginX, marginY);
                
                // To fit into a POT-texture, we extend it towards the right and bottom.
                var minSize:int = MIN_TEXTURE_SIZE / scale;
                var minWidth:Number  = resultRect.width  > minSize ? resultRect.width  : minSize;
                var minHeight:Number = resultRect.height > minSize ? resultRect.height : minSize;
                resultPotRect.setTo(
                    resultRect.x, resultRect.y,
                    getNextPowerOfTwo(minWidth  * scale) / scale,
                    getNextPowerOfTwo(minHeight * scale) / scale);
            }
        }
        
        private function disposePassTextures():void
        {
            for each (var texture:Texture in mPassTextures)
                texture.dispose();
            
            mPassTextures = null;
        }
        
        private function disposeCache():void
        {
            if (mCache)
            {
                if (mCache.texture) mCache.texture.dispose();
                mCache.dispose();
                mCache = null;
            }
        }
      
        
        // flattening
        
        /** @private */
        override starling_internal function compile(object:DisplayObject):QuadBatch
        {
            if (mCache) return mCache;
            else
            {
                var renderSupport:RenderSupport;
                var stage:Stage = object.stage;
                
                if (stage == null) 
                    throw new Error("Filtered object must be on the stage.");
                
                renderSupport = new RenderSupport();
                object.getTransformationMatrix(stage, renderSupport.modelViewMatrix);
                return renderPasses(object, renderSupport, 1.0, true);
            }
        }
		
		/** Applies the filter on a certain display object, rendering the output into the current 
         *  render target. This method is called automatically by Starling's rendering system 
         *  for the object the filter is attached to. */
        override public function render(object:DisplayObject, support:RenderSupport, parentAlpha:Number):void
        {
            // bottom layer
            
            if (mode == FragmentFilterMode.ABOVE)
                object.render(support, parentAlpha);
            
            // center layer
            
            if (mCacheRequested)
            {
                mCacheRequested = false;
                mCache = renderPasses(object, support, 1.0, true);
                disposePassTextures();
            }
            
            if (mCache)
                mCache.render(support, parentAlpha);
            else
                renderPasses(object, support, parentAlpha, false);
            
            // top layer
            
            if (mode == FragmentFilterMode.BELOW)
                object.render(support, parentAlpha);
        }
        
    }
}