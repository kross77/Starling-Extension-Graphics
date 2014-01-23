package starling.display.graphics
{
	import flash.geom.Point;
	
	import starling.display.graphics.StrokeVertex;
	import starling.textures.Texture;
		
	public class PreallocStroke extends Graphic
	{
		protected var _line			:Vector.<StrokeVertex>;
		
		protected var _lineCapacity:int = -1;
		protected var _currentLineCapacity:int = -1;
		protected var _lineCreatedWithCapacity:Boolean = false;
		
		protected static const c_degenerateUseNext:uint = 1;
		protected static const c_degenerateUseLast:uint = 2;
		
		public function PreallocStroke()
		{
			setCapacity(10);
		}
		
		public function get numVertices():int
		{
			return _currentLineCapacity;
		}
		
		override public function dispose():void
		{
			_lineCapacity = 0;
			clear();
			super.dispose();
		
		}

		public function setCapacity(capacity:int) : void
		{
			_lineCapacity = capacity;
			clear();	
		}
		
		public function clear():void
		{
			if(minBounds)
			{
				minBounds.x = minBounds.y = Number.POSITIVE_INFINITY; 
				maxBounds.x = maxBounds.y = Number.NEGATIVE_INFINITY;
			}
			
			if ( _line != null && _lineCapacity == _line.length )
			{
				
			}
			else
			{
			//	if ( _line != null )
			//		StrokeVertex.returnInstances(_line);
			
				_line = new Vector.<StrokeVertex>(_lineCapacity, true); // making the line static in this case
				for ( var i:int = 0; i < _lineCapacity; i++ )
					_line[i] = new StrokeVertex;	
			}
			_currentLineCapacity = 0;
			
			setGeometryInvalid();
		}
		
		public function addDegenerates(destX:Number, destY:Number):void
		{
			if (_currentLineCapacity < 1)
			{
				return;
			}
			var lastVertex:StrokeVertex = _line[_currentLineCapacity-1];
			addVertexPrealloc(lastVertex.x, lastVertex.y, 0.0);
			setLastVertexAsDegenerate(c_degenerateUseLast);
			addVertexPrealloc(destX, destY, 0.0);
			setLastVertexAsDegenerate(c_degenerateUseNext);
		}
		
		protected function setLastVertexAsDegenerate(type:uint):void
		{
			_line[_currentLineCapacity-1].degenerate = type;
			_line[_currentLineCapacity-1].u = 0.0;
		}

		public function addVertexPrealloc( 	x:Number, y:Number, thickness:Number = 1,
							color0:uint = 0xFFFFFF,  alpha0:Number = 1,
							color1:uint = 0xFFFFFF, alpha1:Number = 1 ):void
		{
			var u:Number = 0;
			
			if ( _line.length > 0 && _materialNumTextures > 0 )
			{
				var textures:Vector.<Texture> = _material.textures;
				var prevVertex:StrokeVertex = _line[_currentLineCapacity - 1];
				var dx:Number = x - prevVertex.x;
				var dy:Number = y - prevVertex.y;
				var d:Number = Math.sqrt(dx*dx+dy*dy);
				u = prevVertex.u + (d / textures[0].width);
			}
			
			var r0:Number = (color0 >> 16) / 255;
			var g0:Number = ((color0 & 0x00FF00) >> 8) / 255;
			var b0:Number = (color0 & 0x0000FF) / 255;
			var r1:Number = (color1 >> 16) / 255;
			var g1:Number = ((color1 & 0x00FF00) >> 8) / 255;
			var b1:Number = (color1 & 0x0000FF) / 255;
			
			var v:StrokeVertex = _line[_currentLineCapacity];
			
			v.x = x;
			v.y = y;
			v.r1 = r0;
			v.g1 = g0;
			v.b1 = b0;
			v.a1 = alpha0;
			v.r2 = r1;
			v.g2 = g1;
			v.b2 = b1;
			v.a2 = alpha1;
			v.u = u;
			v.v = 0;
			v.thickness = thickness;
			v.degenerate = 0;
			
			_currentLineCapacity++; // Only change so far from original algorithm
			
			if(x < minBounds.x) 
			{
				minBounds.x = x;
			}
			else if(x > maxBounds.x)
			{
				maxBounds.x = x;
			}
			if(y < minBounds.y)
			{
				minBounds.y = y;
			}
			else if(y > maxBounds.y)
			{
				maxBounds.y = y;
			}
			
			if ( maxBounds.x == Number.NEGATIVE_INFINITY )
				maxBounds.x = x;
			if ( maxBounds.y == Number.NEGATIVE_INFINITY )	
				maxBounds.y = y;
			if ( isInvalid == false )
				setGeometryInvalid();
			
		}
	
		
		public function getVertexPosition(index:int, prealloc:Point = null):Point
		{
			var point:Point = prealloc;
			if ( point == null ) 
				point = new Point();
				
			point.x = _line[index].x;
			point.y = _line[index].y;
			return point;
		}
		
		override protected function buildGeometry():void
		{
			buildGeometryPreAllocatedVectors();
		}
		
	
		protected function buildGeometryPreAllocatedVectors() : void
		{
			if ( _line == null || _line.length == 0 )
				return; // block against odd cases.
				
			// This is the code that uses the preAllocated code path for createPolyLinePreAlloc
			var indexOffset:int = 0;
			
			// Then use the line lenght to pre allocate the vertex vectors
			var numVerts:int = _line.length * 18; // this looks odd, but for each StrokeVertex, we generate 18 verts in createPolyLine
			var numIndices:int = (_line.length - 1) * 6; // this looks odd, but for each StrokeVertex-1, we generate 6 indices in createPolyLine
			
			// In special cases, there is some time to save here. 
			// If the new number of vertices is the same as in the previous list of vertices, there's no need to recreate the buffer of vertices and indices
			if ( vertices == null || numVerts != vertices.length )
			{
				vertices = new Vector.<Number>(numVerts, true);
			}
			if ( indices == null || numIndices != indices.length )
			{
				indices = new Vector.<uint>(numIndices, true);
			}	
			
			createPolyLinePreAlloc( _line, vertices, indices, indexOffset);

			var oldVerticesLength:int = 0; // this is always zero in the old code, even if we use vertices.length in the original code. Not sure why it is here.
			const oneOverVertexStride:Number = 1 / VERTEX_STRIDE;	
			indexOffset += (vertices.length - oldVerticesLength) * oneOverVertexStride;
			
		}
		
		///////////////////////////////////
		// Static helper methods
		///////////////////////////////////
		[inline]
		protected static function createPolyLinePreAlloc( vertices:Vector.<StrokeVertex>, 
												outputVertices:Vector.<Number>, 
												outputIndices:Vector.<uint>, 
												indexOffset:int):void
		{
			
			const numVertices:int = vertices.length;
			const PI:Number = Math.PI;
			var vertCounter:int = 0;
			var indiciesCounter:int = 0;
			var lastD0:Number = 0;
			var lastD1:Number = 0;
			for ( var i:int = 0; i < numVertices; i++ )
			{
				var degenerate:uint = vertices[i].degenerate;
				var idx:uint = i;
				if ( degenerate != 0 ) {
					idx = ( degenerate == c_degenerateUseLast ) ? ( i - 1 ) : ( i + 1 );
				}
				var treatAsFirst:Boolean = ( idx == 0 ) || ( vertices[ idx - 1 ].degenerate > 0 );
				var treatAsLast:Boolean = ( idx == numVertices - 1 ) || ( vertices[ idx + 1 ].degenerate > 0 );
				
				var treatAsRegular:Boolean = treatAsFirst == false && treatAsLast == false;
				
				var idx0:uint = treatAsFirst ? idx : ( idx - 1 );
				var idx2:uint = treatAsLast ? idx : ( idx + 1 );
				
				var v0:StrokeVertex = vertices[idx0];
				var v1:StrokeVertex = vertices[idx];
				var v2:StrokeVertex = vertices[idx2];
				
				var vThickness:Number = v1.thickness;
				
				var v0x:Number = v0.x;
				var v0y:Number = v0.y;
				var v1x:Number = v1.x;
				var v1y:Number = v1.y;
				var v2x:Number = v2.x;
				var v2y:Number = v2.y;
				
				var d0x:Number = v1x - v0x;
				var d0y:Number = v1y - v0y;
				var d1x:Number = v2x - v1x;
				var d1y:Number = v2y - v1y;
				
				if ( treatAsRegular == false )
				{
					if ( treatAsLast )
					{
						v2x += d0x;
						v2y += d0y;
						
						d1x = v2x - v1x;
						d1y = v2y - v1y;
					}
				
					if ( treatAsFirst )
					{
						v0x -= d1x;
						v0y -= d1y;
						
						d0x = v1x - v0x;
						d0y = v1y - v0y;
					}
				}
				
				var d0:Number = Math.sqrt( d0x*d0x + d0y*d0y );
				var d1:Number = Math.sqrt( d1x*d1x + d1y*d1y );
		
				var elbowThickness:Number = vThickness*0.5;
				if ( treatAsRegular )
				{
					if ( d0 == 0 )
						d0 = lastD0;
					else
						lastD0 = d0;
					
					if ( d1 == 0 )
						d1 = lastD1;
					else
						lastD1 = d1;
				
					// Thanks to Tom Clapham for spotting this relationship.
					var dot:Number = (d0x * d1x + d0y * d1y) / (d0 * d1);
					var arcCosDot:Number = Math.acos(dot);
					elbowThickness /= Math.sin( (PI-arcCosDot) * 0.5);
					
					if ( elbowThickness > vThickness * 4 )
					{
						elbowThickness = vThickness * 4;
					}
					
					if ( elbowThickness != elbowThickness ) // faster NaN comparison
					{
						elbowThickness = vThickness*0.5;
					}
				}
				
				var n0x:Number = -d0y / d0;
				var n0y:Number =  d0x / d0;
				var n1x:Number = -d1y / d1;
				var n1y:Number =  d1x / d1;
				
				var cnx:Number = n0x + n1x;
				var cny:Number = n0y + n1y;
				
				var c:Number = (1/Math.sqrt( cnx*cnx + cny*cny )) * elbowThickness;
				cnx *= c;
				cny *= c;
				
				var v1xPos:Number = v1x + cnx;
				var v1yPos:Number = v1y + cny;
				var v1xNeg:Number = ( degenerate ) ? v1xPos : ( v1x - cnx );
				var v1yNeg:Number = ( degenerate ) ? v1yPos : ( v1y - cny );
			
				outputVertices[vertCounter++] = v1xPos;
				outputVertices[vertCounter++] = v1yPos;
				outputVertices[vertCounter++] = 0;
				outputVertices[vertCounter++] = v1.r2;
				outputVertices[vertCounter++] = v1.g2;
				outputVertices[vertCounter++] = v1.b2;
				outputVertices[vertCounter++] = v1.a2;
				outputVertices[vertCounter++] = v1.u;
				outputVertices[vertCounter++] = 1;
				outputVertices[vertCounter++] = v1xNeg;
				outputVertices[vertCounter++] = v1yNeg;
				outputVertices[vertCounter++] = 0;
				outputVertices[vertCounter++] = v1.r1;
				outputVertices[vertCounter++] = v1.g1;
				outputVertices[vertCounter++] = v1.b1;
				outputVertices[vertCounter++] = v1.a1;
				outputVertices[vertCounter++] = v1.u;
				outputVertices[vertCounter++] = 0;
				
				if ( i < numVertices - 1 )
				{
					var i2:int = indexOffset + (i << 1);
					outputIndices[indiciesCounter++] = i2;
					outputIndices[indiciesCounter++] = i2+2;
					outputIndices[indiciesCounter++] = i2+1;
					outputIndices[indiciesCounter++] = i2+1;
					outputIndices[indiciesCounter++] = i2+2;
					outputIndices[indiciesCounter++] = i2+3;
				}
				
			}
		}
		
		override protected function shapeHitTestLocalInternal( localX:Number, localY:Number ):Boolean
		{
			if ( _line == null ) return false;
			if ( _line.length < 2 ) return false;
			
			var numLines:int = _line.length;
			
			for ( var i: int = 1; i < numLines; i++ )
			{
				var v0:StrokeVertex = _line[i - 1];
				var v1:StrokeVertex = _line[i];
				
				var lineLengthSquared:Number = (v1.x - v0.x) * (v1.x - v0.x) + (v1.y - v0.y) * (v1.y - v0.y);
				
				var interpolation:Number = ( ( ( localX - v0.x ) * ( v1.x - v0.x ) ) + ( ( localY - v0.y ) * ( v1.y - v0.y ) ) )  /	( lineLengthSquared );
				if( interpolation < 0.0 || interpolation > 1.0 )
					continue;   // closest point does not fall within the line segment
					
				var intersectionX:Number = v0.x + interpolation * ( v1.x - v0.x );
				var intersectionY:Number = v0.y + interpolation * ( v1.y - v0.y );
				
				var distanceSquared:Number = (localX - intersectionX) * (localX - intersectionX) + (localY - intersectionY) * (localY - intersectionY);
				
				var intersectThickness:Number = (v0.thickness * (1.0 - interpolation) + v1.thickness * interpolation); // Support for varying thicknesses
				
				intersectThickness += _precisionHitTestDistance;
				
				if ( distanceSquared <= intersectThickness * intersectThickness)
					return true;
			}
				
			return false;
		}
		
	}
}