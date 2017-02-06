//
//  PODModel.mm
//
//  Created by Jack Wright on 1/15/12.
//  Copyright (c) 2012 JackCraft. All rights reserved.
//

#import "PODModel.h"

@implementation PODModel

@synthesize texture0 = _texture0, texture1 = _texture1;
@synthesize lightDir = _lightDir;
@synthesize globalLight = _globalLight;
@synthesize ambient = _ambient;
@synthesize shader = _shader;
@synthesize lightViewMatrix = _lightViewMatrix;
@synthesize biasMatrix = _biasMatrix;

- (id) initWithFile:(NSString *)filename texture:(GLuint)texture shader:(Shader *)shader;
{
	self = [super init];
	if(self != nil)
	{
		_texture0 = texture;
		_shader = shader;

		[self loadFile:filename];

		_lightViewMatrix = PVRTMat4::Identity();
		_biasMatrix = PVRTMat4::Identity();
		
	}
	
	return self;
	
} // init


- (id) initFromMemory:(const char *)name size:(const size_t)size texture:(GLuint)texture shader:(Shader *)shader;
{
	self = [super init];
	if(self != nil)
	{
		_texture0 = texture;
		_shader = shader;

		[self loadFromMemory:name size:size];
	}
	
	return self;
	
} // init


- (void) dealloc
{
	glDeleteBuffers(_scene.nNumMesh, &_vertexBuffer[0]);
    glDeleteBuffers(_scene.nNumMesh, &_vertexIndexBuffer[0]);
    glDeleteVertexArraysOES(_scene.nNumMesh, &_vertexArray[0]);
	
//	[super dealloc];

}


- (void) loadVAOs;
{
	// create a VAO and VBOs for each mesh
	_vertexArray = new GLuint[_scene.nNumMesh];
	_vertexBuffer = new GLuint[_scene.nNumMesh];
	_vertexIndexBuffer = new GLuint[_scene.nNumMesh];
	
	/*
	 Load vertex data of all meshes in the scene into VBOs
	 
	 The meshes have been exported with the "Interleave Vectors" option,
	 so all data is interleaved in the buffer at pMesh->pInterleaved.
	 Interleaving data improves the memory access pattern and cache efficiency,
	 thus it can be read faster by the hardware.
	 */
	
	glGenVertexArraysOES(_scene.nNumMesh, _vertexArray);
	
	for (unsigned int i = 0; i < _scene.nNumMesh; ++i)
	{
		
		glBindVertexArrayOES(_vertexArray[i]);
		
		glGenBuffers(1, &_vertexBuffer[i]);
		
		// Load vertex data into buffer object
		SPODMesh& Mesh = _scene.pMesh[i];
		unsigned int uiSize = Mesh.nNumVertex * Mesh.sVertex.nStride;
		glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer[i]);
		glBufferData(GL_ARRAY_BUFFER, uiSize, Mesh.pInterleaved, GL_STATIC_DRAW);
		if (Mesh.sFaces.pData)
		{
			glGenBuffers(1, &_vertexIndexBuffer[i]);
			uiSize = PVRTModelPODCountIndices(Mesh) * sizeof(GLshort);
			glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _vertexIndexBuffer[i]);
			glBufferData(GL_ELEMENT_ARRAY_BUFFER, uiSize, Mesh.sFaces.pData, GL_STATIC_DRAW);
		}
		GLuint vertexAttrib = [_shader attributeHandle:@"inVertex"];
		glEnableVertexAttribArray(vertexAttrib);
		glVertexAttribPointer(vertexAttrib, 3, GL_FLOAT, GL_FALSE, Mesh.sVertex.nStride, Mesh.sVertex.pData);

		vertexAttrib = [_shader attributeHandle:@"inNormal"];
		glEnableVertexAttribArray(vertexAttrib);
		glVertexAttribPointer(vertexAttrib, 3, GL_FLOAT, GL_FALSE, Mesh.sNormals.nStride, Mesh.sNormals.pData);
		
		if (Mesh.nNumUVW > 0) {
			vertexAttrib = [_shader attributeHandle:@"inTexCoord"];
			glEnableVertexAttribArray(vertexAttrib);
			glVertexAttribPointer(vertexAttrib, 2, GL_FLOAT, GL_FALSE, Mesh.psUVW[0].nStride, Mesh.psUVW[0].pData);
		}
		
		if(Mesh.sBoneIdx.n && Mesh.sBoneWeight.n) {
			vertexAttrib = [_shader attributeHandle:@"inBoneIndex"];
			glEnableVertexAttribArray(vertexAttrib);
			glVertexAttribPointer(vertexAttrib, Mesh.sBoneIdx.n, GL_UNSIGNED_BYTE, GL_FALSE, Mesh.sBoneIdx.nStride, Mesh.sBoneIdx.pData);

			vertexAttrib = [_shader attributeHandle:@"inBoneWeights"];
			glEnableVertexAttribArray(vertexAttrib);
			glVertexAttribPointer(vertexAttrib, Mesh.sBoneWeight.n, GL_FLOAT, GL_TRUE, Mesh.sBoneWeight.nStride, Mesh.sBoneWeight.pData);
		}
	}
	
	glBindVertexArrayOES(0);

} // loadVAOs


- (BOOL) loadFile:(NSString *)filename;
{
	
	NSBundle*				bundle = [NSBundle mainBundle];
		
	EPVRTError error = _scene.ReadFromFile([[bundle pathForResource:filename ofType:@"pod"] UTF8String]);
	
	if (error != PVR_SUCCESS) {
		
		NSLog(@"Failure to load POD file: %@, error = %d", filename, error);
		return false;
	}
	
	[self loadVAOs];
	
	return true;

} // loadFile


- (BOOL) loadFromMemory:(const char *)name size:(const size_t)size
{
	
	EPVRTError error = _scene.ReadFromMemory((const char *)name, (const size_t)size);
	
	if (error != PVR_SUCCESS) {
		
		NSLog(@"Failure to read POD model from memory: %s, error = %d", name, error);
		return false;
	}
	
	[self loadVAOs];

	return true;
	
} // loadFromMemory
	

- (void) setFrame:(float)frame;
{
	
	_scene.SetFrame(frame);

} // update


- (void) drawMesh:(int)i32NodeIndex
{
	
	SPODNode& Node = _scene.pNode[i32NodeIndex];
	SPODMesh& Mesh = _scene.pMesh[Node.nIdx];
	
#if ASIAN
	if (0)
#else
	if(Mesh.sBoneIdx.n && Mesh.sBoneWeight.n)
#endif
	{
		/*
		 There is a limit to the number of bone matrices that you can pass to the shader so we have
		 chosen to limit the number of bone matrices that affect a mesh to 8. However, this does
		 not mean our character can only have a skeleton consisting of 8 bones. We can get around
		 this by using bone batching where the character is split up into sub-meshes that are only
		 affected by a sub set of the overal skeleton. This is why we have this for loop that
		 iterates through the bone batches contained with the SPODMesh.
		 */
		for (int i32Batch = 0; i32Batch < Mesh.sBoneBatches.nBatchCnt; ++i32Batch)
		{
			// Set the number of bones that will influence each vertex in the mesh
			glUniform1i([_shader uniformLocation:@"BoneCount"], Mesh.sBoneIdx.n);
			
			// Go through the bones for the current bone batch
			PVRTMat4 amBoneWorld[8];
			PVRTMat3 afBoneWorldIT[8];
			
			int i32Count = Mesh.sBoneBatches.pnBatchBoneCnt[i32Batch];
			
			for(int i = 0; i < i32Count; ++i)
			{
				// Get the Node of the bone
				int i32NodeID = Mesh.sBoneBatches.pnBatches[i32Batch * Mesh.sBoneBatches.nBatchBoneMax + i];
				
				// Get the World transformation matrix for this bone
				_scene.GetWorldMatrix(amBoneWorld[i], _scene.pNode[i32NodeID]);
				
				// Calculate the inverse transpose of the 3x3 rotation/scale part for correct lighting
				afBoneWorldIT[i] = PVRTMat3(amBoneWorld[i]).inverse().transpose();
			}
			
			glUniformMatrix4fv([_shader uniformLocation:@"BoneMatrixArray"], i32Count, GL_FALSE, amBoneWorld[0].ptr());
			glUniformMatrix3fv([_shader uniformLocation:@"BoneMatrixArrayIT"], i32Count, GL_FALSE, afBoneWorldIT[0].ptr());
			
			/*
			 As we are using bone batching we don't want to draw all the faces contained within pMesh, we only want
			 to draw the ones that are in the current batch. To do this we pass to the drawMesh function the offset
			 to the start of the current batch of triangles (Mesh.sBoneBatches.pnBatchOffset[i32Batch]) and the
			 total number of triangles to draw (i32Tris)
			 */
			int i32Tris;
			if(i32Batch+1 < Mesh.sBoneBatches.nBatchCnt)
				i32Tris = Mesh.sBoneBatches.pnBatchOffset[i32Batch+1] - Mesh.sBoneBatches.pnBatchOffset[i32Batch];
			else
				i32Tris = Mesh.nNumFaces - Mesh.sBoneBatches.pnBatchOffset[i32Batch];
			
			// Draw the mesh
			glDrawElements(GL_TRIANGLES, i32Tris * 3, GL_UNSIGNED_SHORT, &((unsigned short*)0)[3 * Mesh.sBoneBatches.pnBatchOffset[i32Batch]]);
		}
		
	}
	else
	{
		PVRTMat4 mModelView;
		
		PVRTMatrixMultiply(mModelView, _transform, _lightViewMatrix);
		
		mModelView *= _biasMatrix;
		
		glUniformMatrix4fv([_shader uniformLocation:@"ModelViewMatrix"], 1, GL_FALSE, mModelView.ptr());

		glUniform1i([_shader uniformLocation:@"BoneCount"], 0);
		
		glDrawElements(GL_TRIANGLES, Mesh.nNumFaces*3, GL_UNSIGNED_SHORT, 0);
	}
	
} // drawMesh


- (void) drawWithTransform:(PVRTMat4)transform mProjection:(PVRTMat4)projection;
{
	_transform = transform;
	_mProjection = projection;
	[self draw];
	
} // drawWithTransform


- (void) draw;
{
	
	[_shader useShader];
    
	PVRTVec4 vLightDirWorld = self.lightDir; // PVRTVec4( -1, 0, -1, 0 );
	
	glUniform3fv([_shader uniformLocation:@"LightDirWorld"], 1, &vLightDirWorld.x);
	
	// ambient light for the model
	glUniform1f([_shader uniformLocation:@"ambient"], _ambient);
	
	// Pass the projection matrix to the shader
	glUniformMatrix4fv([_shader uniformLocation:@"ViewProjMatrix"], 1, GL_FALSE, _mProjection.ptr());
	
	glActiveTexture(GL_TEXTURE0);
	glBindTexture(GL_TEXTURE_2D, _texture0);
	// Set the sampler2D uniform to corresponding texture unit
	glUniform1i([_shader uniformLocation:@"sTexture"], 0);
	
	
	/*
	 A scene is composed of nodes. There are 3 types of nodes:
	 - MeshNodes :
	 references a mesh in the pMesh[].
	 These nodes are at the beginning of the pNode[] array.
	 And there are nNumMeshNode number of them.
	 This way the .pod format can instantiate several times the same mesh
	 with different attributes.
	 - lights
	 - cameras
	 To draw a scene, you must go through all the MeshNodes and draw the referenced meshes.
	 */
	for (unsigned int i32NodeIndex = 0; i32NodeIndex < _scene.nNumMeshNode; ++i32NodeIndex)
	{
		SPODNode& Node = _scene.pNode[i32NodeIndex];
		
		// Get the node model matrix
		PVRTMat4 mWorld;
		mWorld = _scene.GetWorldMatrix(Node);
//
//		// Set up shader uniforms
//		PVRTMat4 mModelViewProj;
//		mModelViewProj = _mProjection * mWorld;
//		glUniformMatrix4fv([_shader uniformLocation:@"MVPMatrix"], 1, GL_FALSE, mModelViewProj.ptr());
		
		PVRTMat4 mModelView;
		
		PVRTMatrixMultiply(mModelView, _transform, _lightViewMatrix);
		
		mModelView *= _biasMatrix;
		
		glUniformMatrix4fv([_shader uniformLocation:@"ModelViewMatrix"], 1, GL_FALSE, mModelView.ptr());
		

		
		PVRTVec4 vLightDirModel;
		vLightDirModel = mWorld.inverse() * vLightDirWorld;
		glUniform3fv([_shader uniformLocation:@"LightDirModel"], 1, &vLightDirModel.x);
		
		glBindVertexArrayOES(_vertexArray[i32NodeIndex]);
		
		[self drawMesh:i32NodeIndex];
		
	}

	glBindVertexArrayOES(0);

} // draw


@end
