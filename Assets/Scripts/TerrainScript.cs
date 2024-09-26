using UnityEngine;
using System.Linq;

//[ExecuteInEditMode]
public class TerrainScript : MonoBehaviour {

    [SerializeField, Range(8, 2048)]
    int Size = 256;

    [SerializeField, Range(0, 10f)]
    float Amplitude;

    float lastAmplitude = 1f;

    [SerializeField, Range(0, 10)]
    float Frequency;

    [SerializeField, Range(1, 32)]
    int Octaves;

    [SerializeField, Range(0f, 1f)]
    float Persistence;

    [SerializeField, Range(1f, 10f)]
    float Lacunarity;

    public ComputeShader NoiseTextureCS;

    [SerializeField]
    Texture2D SampleHeightMap;

    [SerializeField]
    bool Generated = true;


    float[] NoiseArr;
    ComputeBuffer NoiseBuffer;
    RenderTexture GeneratedHeightMap;
    Material sharedMat;


    const int LOCAL_WORK_GROUPS_X = 8;
    const int LOCAL_WORK_GROUPS_Y = 8;


    void Awake(){
        sharedMat = this.GetComponent<Renderer>().sharedMaterial;
    }

    void OnEnable() {
        sharedMat.SetFloat("_Amplitude", Amplitude);
        NoiseArr = new float[Size*Size];
        NoiseBuffer = new ComputeBuffer(Size*Size, 4);
        GeneratedHeightMap = new RenderTexture((int)Size, (int)Size, 0);

        if (Generated) {
            int threadGroupsX = Mathf.CeilToInt((float)Size / (float)LOCAL_WORK_GROUPS_X);
            int threadGroupsY = Mathf.CeilToInt((float)Size / (float)LOCAL_WORK_GROUPS_Y);

            GeneratedHeightMap.wrapMode = TextureWrapMode.Clamp;
            GeneratedHeightMap.enableRandomWrite = true;

            NoiseTextureCS.SetBuffer(0, "NoiseBuffer", NoiseBuffer);
            NoiseTextureCS.SetBuffer(1, "NoiseBuffer", NoiseBuffer);
            NoiseTextureCS.SetInt("_Size", Size*1);
            NoiseTextureCS.SetFloat("_Frequency", Frequency);
            NoiseTextureCS.SetInt("_Octaves", Octaves);
            NoiseTextureCS.SetFloat("_Persistence", Persistence);
            NoiseTextureCS.SetFloat("_Lacunarity", Lacunarity);

            NoiseTextureCS.Dispatch(0, threadGroupsX, threadGroupsY, 1);
        
            NoiseBuffer.GetData(NoiseArr);
            float maxNoise = NoiseArr.Max();
            NoiseTextureCS.SetFloat("_MaxNoise", maxNoise);
            NoiseTextureCS.SetTexture(1, "GeneratedHeightMap", GeneratedHeightMap);
        
            NoiseTextureCS.Dispatch(1, threadGroupsX, threadGroupsY, 1);

            sharedMat.SetTexture("_HeightMap", GeneratedHeightMap);
        }

        else { 
            sharedMat.SetTexture("_HeightMap", SampleHeightMap);
        }
    }

    void OnDisable() {
        NoiseArr = null;

        NoiseBuffer.Release();
        NoiseBuffer = null;

        Destroy(GeneratedHeightMap);
        //DestroyImmediate(GeneratedHeightMap);
    }

    void OnValidate() {
        if (NoiseBuffer != null & enabled) {
            if (lastAmplitude == Amplitude){
                OnDisable();
                OnEnable();
            }
        }
    }

    void Update() {
        lastAmplitude = Amplitude;
        sharedMat.SetFloat("_Amplitude", Amplitude);
    }
}
